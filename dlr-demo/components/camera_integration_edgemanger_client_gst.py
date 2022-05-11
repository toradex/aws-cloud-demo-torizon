#
# Copyright 2010-2021 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
import cv2
import numpy as np
import random
import argparse
import time
import json
import awsiot.greengrasscoreipc
from awsiot.greengrasscoreipc.model import (
    QOS,
    PublishToIoTCoreRequest
)
import math
import agent_pb2_grpc
import grpc
from agent_pb2 import (ListModelsRequest, LoadModelRequest, PredictRequest,
                       UnLoadModelRequest, DescribeModelRequest, CaptureDataRequest, Tensor, 
                       TensorMetadata, Timestamp)
import signal
import sys
import uuid

#import boto3
import threading,os


import gi
import cairo
gi.require_version('Gst', '1.0')
gi.require_foreign('cairo')
from gi.repository import Gst, GObject


parser = argparse.ArgumentParser()
parser.add_argument('-s', '--stream', action='store', type=str, required=True, dest='stream_path', help='Video source URL')
parser.add_argument('-c', '--model-component', action='store', type=str, required=True, dest='model_component_name', help='Name of the GGv2 component containing the model')
parser.add_argument('-m', '--model-name', action='store', type=str, required=True, dest='model_name', help='Friendly name of the model from Edge Packaging Job')
parser.add_argument('-q', '--quantized', action='store', type=str, required=True, dest='quant', help='Is the model quantized?')
parser.add_argument('-a', '--capture', action='store', type=str, required=True, dest='capture_data', default=False, help='Capture inference metadata and raw output')

args = parser.parse_args()

stream_path = args.stream_path
#stream_path = "/19669876-hd.mp4"
model_component_name = args.model_component_name
model_name = args.model_name
quant = args.quant == 'True'

my_label = "unknown"
if (args.capture_data == "v2"):
    my_label = "bus"
print ('Video source is at ' + stream_path)
print ('Model Greengrass v2 component name is ' + model_component_name)
print ('Model name is ' + model_name)
print ('Model is quantized: ' + str(quant))
print ('The label is ' + my_label)

model_url = '/greengrass/v2/work/' + model_component_name
tensor_name = 'normalized_input_image_tensor'
SIZE = 300
tensor_shape = [1, SIZE, SIZE, 3]

inference_result_topic = "em/inference"
ipc_client = awsiot.greengrasscoreipc.connect()

channel = grpc.insecure_channel('unix:///tmp/sagemaker_edge_agent_example.sock')
edge_manager_client = agent_pb2_grpc.AgentStub(channel)

#kinesis_client = boto3.client('kinesis', region_name='us-east-1')


class ObjectDetection:
    """NNStreamer example for Object Detection."""

    def __init__(self, argv=None):
        #self.loop = None
        self.pipeline = None
        self.running = False
        self.video_caps = None
        self.video_postion = None

        self.engine = None

        self.objects = []
        self.scores = []
        self.bounding_boxes = None
        self.inference_ns = 0

        self.VIDEO_WIDTH = 1280
        self.VIDEO_HEIGHT = 720
        self.MODEL_WIDTH = 300
        self.MODEL_HEIGHT = 300

        #self.dlr_init()
        GObject.threads_init()

        # Gstreamer Init
        Gst.init(argv)

    def dlr_init(self):
        self.engine = DLRModel(Model_Dir, 'cpu')

    def run(self):
        """Init pipeline and run example.
        :return: None
        """

        print("Run: NNStreamer example for object detection.")

        # main loop
        #self.loop = GObject.MainLoop()

        gst_launch_cmdline = ''
        if len(str(stream_path).split('.')) > 1:
            gst_launch_cmdline = ' filesrc location={:s} ! matroskademux ! h264parse !'.format(stream_path)
        else:
            gst_launch_cmdline = 'v4l2src device=/dev/video{:s} do-timestamp=True !'.format(stream_path)
        gst_launch_cmdline += '  queue name=thread-decode max-size-buffers=2 ! vpudec ! imxvideoconvert_g2d !'
        gst_launch_cmdline += '  video/x-raw,width={:d},height={:d} ! tee name=t '.format(self.VIDEO_WIDTH, self.VIDEO_HEIGHT)
        gst_launch_cmdline += ' t. ! queue name=thread-nn max-size-buffers=2 leaky=2 !'
        gst_launch_cmdline += '  imxvideoconvert_g2d !'
        gst_launch_cmdline += '  video/x-raw,width={:d},height={:d},format=RGBA !'.format(self.MODEL_WIDTH, self.MODEL_HEIGHT)
        gst_launch_cmdline += '  videoconvert ! video/x-raw,format=RGB !'
        gst_launch_cmdline += '  appsink name=sink drop=True max-buffers=1 emit-signals=True sync=False'
        gst_launch_cmdline += ' t. ! queue name=thread-img max-size-buffers=2 !'
        gst_launch_cmdline += ' cairooverlay name=drawlay ! imxvideoconvert_g2d ! videoconvert !'

        gst_launch_cmdline += ' waylandsink sync=True'
        #gst_launch_cmdline += ' tee name=tsink'
        #gst_launch_cmdline += ' tsink. ! queue name=thread-display max-size-buffers=2 leaky=0 ! waylandsink'
        #gst_launch_cmdline += ' tsink. ! queue name=thread-encode max-size-buffers=2 leaky=0 !'
        #gst_launch_cmdline += ' x264enc !'  # mp4
        #gst_launch_cmdline += ' vpuenc_h264 !' # mkv
        #gst_launch_cmdline += '  rtph264pay ! udpsink host=10.192.208.100 port=5000'

        print(gst_launch_cmdline)

        self.pipeline = Gst.parse_launch(gst_launch_cmdline)

        #bus = self.pipeline.get_bus()
        #bus.add_signal_watch()
        #bus.connect('message', self.on_bus_message)

        appsink = self.pipeline.get_by_name('sink')
        appsink.connect("new-sample", self.on_new_frame, appsink)

        drawlay = self.pipeline.get_by_name('drawlay')
        drawlay.connect('draw', self.draw_overlay_cb)
        drawlay.connect('caps-changed', self.prepare_overlay_cb)

        #get the static source pad of the element
        #drawpad = drawlay.get_static_pad('src')
        #add the probe to the pad obtained in previous solution
        #probeID = drawpad.add_probe(Gst.PadProbeType.BUFFER, self.probe_callback)

        self.pipeline.set_state(Gst.State.PLAYING)
        self.running = True

        # run main loop
        self.loop()

        # quit when received eos or error message
        self.running = False
        self.pipeline.set_state(Gst.State.NULL)

        #bus.remove_signal_watch()

    # Inference
    def inference(self, img):

        nn_input = img
        #img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        #nn_input=cv2.resize(img, (self.MODEL_WIDTH, self.MODEL_HEIGHT))

        #Run the model
        tbefore = time.time_ns()

        request = PredictRequest(name=model_name, tensors=[Tensor(tensor_metadata=TensorMetadata(
            name=tensor_name, data_type=5, shape=tensor_shape), byte_data=img.tobytes())])
        response = edge_manager_client.Predict(request)
        inference_result = process_output_tensor(response)

        tafter = time.time_ns()
        self.inference_ns = tafter-tbefore

        self.objects = inference_result["labels"]
        self.scores = inference_result["scores"]
        self.bounding_boxes = inference_result["boxes"]


    # Pipeline 1 output
    def on_new_frame(self, sink, data):

        sample = sink.emit("pull-sample")
        captured_gst_buf = sample.get_buffer()
        caps = sample.get_caps()
        im_height_in = caps.get_structure(0).get_value('height')
        im_width_in = caps.get_structure(0).get_value('width')
        mem = captured_gst_buf.get_all_memory()
        success, arr = mem.map(Gst.MapFlags.READ)
        img = np.ndarray((im_height_in,im_width_in,3),buffer=arr.data,dtype=np.uint8)
        self.inference(img)
        mem.unmap(arr)
        return Gst.FlowReturn.OK


    def probe_callback(self, pad, info):

        buf = info.get_buffer()
        #dts = buf.dts
        pts = buf.pts

        #print('dts', dts)
        #print('pts', pts)
        buf.pts = pts + self.inference_ns
        #print('pts', pts)

        return Gst.PadProbeReturn.OK

    # @brief Store the information from the caps that we are interested in.
    def prepare_overlay_cb(self, overlay, caps):

        self.video_caps = caps
        print("caps is enabled")

    # @brief Main Loop.
    def loop(self):

        bus = self.pipeline.get_bus()
        while True:
            message = bus.timed_pop_filtered(100 * Gst.MSECOND, Gst.MessageType.ANY)
            if message:
                if message.type == Gst.MessageType.ERROR:
                    err,debug = message.parse_error()
                    print("ERROR bus 1:",err,debug)
                    self.pipeline.set_state(Gst.State.NULL)
                    quit()

                elif message.type == Gst.MessageType.WARNING:
                    err,debug = message.parse_warning()
                    print("WARNING bus 1:",err,debug)

                elif message.type == Gst.MessageType.STATE_CHANGED:
                    old_state, new_state, pending_state = message.parse_state_changed()
                    print("INFO: state on bus 2 changed from ",old_state," To: ",new_state)
                else:
                    pass
                    #print("debug:", message)
            else:
                pos = self.pipeline.query_position(Gst.Format.TIME)
                #print("seek:", self.video_postion, pos)
                if self.running and pos == self.video_postion:
                    print("replay")
                    time.sleep(1)
                    self.pipeline.seek_simple(Gst.Format.TIME, Gst.SeekFlags.FLUSH, 1 * Gst.SECOND)
                    time.sleep(1)
                    self.pipeline.set_state(Gst.State.PLAYING)
                else:
                    self.video_postion = pos

    # @brief Callback to draw the overlay.
    def draw_overlay_cb(self, overlay, context, timestamp, duration):

        #print("timestamp", timestamp)
        if self.video_caps == None or not self.running:
            return

        timestamp = timestamp - duration

        drawed = 0
        context.select_font_face('Sans', cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
        context.set_font_size(20.0)

        if len(self.objects) == 0:
            return

        i = 0
        while (self.scores[i]>0.5):
            object_id=int(self.objects[i])

            #label = class_names[object_id]
            label = label2string[object_id]
            boxes = self.bounding_boxes
            box = [boxes[i*4], boxes[i*4+1], boxes[i*4+2], boxes[i*4+3]]

            x1=int(box[1] * self.VIDEO_WIDTH)
            y1=int(box[0] * self.VIDEO_HEIGHT)
            x2=int(box[3] * self.VIDEO_WIDTH)
            y2=int(box[2] * self.VIDEO_HEIGHT)

            x = x1
            y = y1
            width = x2 - x1
            height = y2 -y1

            # draw rectangle
            context.rectangle(x, y, width, height)
            context.set_source_rgb(1, 0, 0)
            context.set_line_width(1.5)
            context.stroke()
            context.fill_preserve()

            # draw title
            context.move_to(x + 5, y + 25)
            context.text_path(label)
            context.set_source_rgb(1, 0, 0)
            context.fill_preserve()
            context.set_source_rgb(1, 1, 1)
            context.set_line_width(0.3)
            context.stroke()
            context.fill_preserve()

            i += 1
            if i >= 10:
                break

def v4l2_camera_pipeline(width, height, device, frate,
                         leaky="leaky=downstream max-size-buffers=1"):

    return (("v4l2src device={} ! video/x-raw,width={},height={},framerate={} "\
             "! queue {} ! videoconvert ! appsink").format(device, width,
                                                              height, frate,
                                                              leaky))


def v4l2_video_pipeline(device, leaky="leaky=downstream max-size-buffers=1"):

    return (("filesrc location={} ! qtdemux name=d d.video_0 ! decodebin ! queue {} ! queue ! imxvideoconvert_g2d ! videoconvert ! "\
             "appsink").format(device, leaky))

stop_sigterm = False

# When the component is stopped.
def sigterm_handler(signum, frame):
    global edge_manager_client
    try:
        print ('In sigterm_handler..........')
        stop_sigterm = True
        time.sleep(1)
        response = edge_manager_client.UnLoadModel(UnLoadModelRequest(name=model_name))
        sys.exit(0)
    except Exception as e:
        print ('Model failed to unload')
        print (e)
        sys.exit(-1)

signal.signal(signal.SIGINT, sigterm_handler)
signal.signal(signal.SIGTERM, sigterm_handler)

def preprocess_frame(captured_frame):

    if not quant:
        frame = resize_short_within(captured_frame, short=SIZE, max_size=SIZE * 2)
        scaled_frame = cv2.resize(frame, (SIZE, int(SIZE/4 * 3 )))
        scaled_frame = cv2.copyMakeBorder(scaled_frame, int(SIZE / 8), int(SIZE / 8),
                                    0, 0, cv2.BORDER_CONSTANT, value=(0, 0, 0))
        scaled_frame = np.asarray(scaled_frame)
        # normalization according to https://github.com/tensorflow/tensorflow/blob/
        # a4dfb8d1a71385bd6d122e4f27f86dcebb96712d/tensorflow/python/keras/applications/imagenet_utils.py#L259
        scaled_frame = (scaled_frame/127.5).astype(np.float32)
        scaled_frame -= 1.
        return scaled_frame
    
    else:
        img = cv2.cvtColor(captured_frame, cv2.COLOR_BGR2RGB)
        img = cv2.resize(img, (SIZE,SIZE))
        scaled_frame = img.astype(np.uint8)
        return scaled_frame

label2string = {
        0:   "person",
        1:   "bicycle",
        2:   "car",
        3:   "motorcycle",
        4:   "airplane",
        5:   "bus",
        #5:   my_label,
        6:   "train",
        7:   "truck",
        8:   "boat",
        9:   "traffic light",
        10:  "fire hydrant",
        12:  "stop sign",
        13:  "parking meter",
        14:  "bench",
        15:  "bird",
        16:  "cat",
        17:  "dog",
        18:  "horse",
        19:  "sheep",
        20:  "cow",
        21:  "elephant",
        22:  "bear",
        23:  "zebra",
        24:  "giraffe",
        26:  "backpack",
        27:  "umbrella",
        30:  "handbag",
        31:  "tie",
        32:  "suitcase",
        33:  "frisbee",
        34:  "skis",
        35:  "snowboard",
        36:  "sports ball",
        37:  "kite",
        38:  "baseball bat",
        39:  "baseball glove",
        40:  "skateboard",
        41:  "surfboard",
        42:  "tennis racket",
        43:  "bottle",
        45:  "wine glass",
        46:  "cup",
        47:  "fork",
        48:  "knife",
        49:  "spoon",
        50:  "bowl",
        51:  "banana",
        52:  "apple",
        53:  "sandwich",
        54:  "orange",
        55:  "broccoli",
        56:  "carrot",
        57:  "hot dog",
        58:  "pizza",
        59:  "donut",
        60:  "cake",
        61:  "chair",
        62:  "couch",
        63:  "potted plant",
        64:  "bed",
        66:  "dining table",
        69:  "toilet",
        71:  "tv",
        72:  "laptop",
        73:  "mouse",
        74:  "remote",
        75:  "keyboard",
        76:  "cell phone",
        77:  "microwave",
        78:  "oven",
        79:  "toaster",
        80:  "sink",
        81:  "refrigerator",
        83:  "book",
        84:  "clock",
        85:  "vase",
        86:  "scissors",
        87:  "teddy bear",
        88:  "hair drier",
        89:  "toothbrush"}

# read output tensors and append them to matrix
def process_output_tensor(response):

    tensors = response.tensors
    detections = {}
    deserialized_bytes = np.frombuffer(tensors[0].byte_data, dtype=np.float32)
    detections["boxes"] = np.asarray(deserialized_bytes).tolist()
    deserialized_bytes = np.frombuffer(tensors[1].byte_data, dtype=np.float32)
    detections["labels"] = np.asarray(deserialized_bytes)
    deserialized_bytes = np.frombuffer(tensors[2].byte_data, dtype=np.float32)
    detections["scores"] = np.asarray(deserialized_bytes).tolist()
    deserialized_bytes = np.frombuffer(tensors[3].byte_data, dtype=np.int32)
    detections["number"] = np.asarray(deserialized_bytes).tolist()

    return detections

# IPC publish to IoT Core
def publish_results_to_iot_core (message):
    # Publish highest confidence result to AWS IoT Core
    global ipc_client
    request = PublishToIoTCoreRequest()
    request.topic_name = inference_result_topic
    request.payload = bytes(json.dumps(message), "utf-8")
    request.qos = QOS.AT_LEAST_ONCE
    operation = ipc_client.new_publish_to_iot_core()
    operation.activate(request)
    future = operation.get_response()
    future.result(10)

def run():
    try:
        print("Tring to unload model first.")
        response = edge_manager_client.UnLoadModel(UnLoadModelRequest(name=model_name))
    except Exception as e:
        pass

    while (True):
        try:
            response = edge_manager_client.LoadModel(
                LoadModelRequest(url=model_url, name=model_name))
            break
        except Exception as e:
            print('Model failed to load')
            sys.exit(-1)

    os.environ["XDG_RUNTIME_DIR"] = "/run/user/0"
    os.environ["QT_QPA_PLATFORM"] = "wayland"

    example = ObjectDetection()
    example.run()



## Scaling functions
def _get_interp_method(interp, sizes=()):
    """Get the interpolation method for resize functions.
    The major purpose of this function is to wrap a random interp method selection
    and a auto-estimation method.
​
    Parameters
    ----------
    interp : int
        interpolation method for all resizing operations
​
        Possible values:
        0: Nearest Neighbors Interpolation.
        1: Bilinear interpolation.
        2: Area-based (resampling using pixel area relation). It may be a
        preferred method for image decimation, as it gives moire-free
        results. But when the image is zoomed, it is similar to the Nearest
        Neighbors method. (used by default).
        3: Bicubic interpolation over 4x4 pixel neighborhood.
        4: Lanczos interpolation over 8x8 pixel neighborhood.
        9: Cubic for enlarge, area for shrink, bilinear for others
        10: Random select from interpolation method metioned above.
        Note:
        When shrinking an image, it will generally look best with AREA-based
        interpolation, whereas, when enlarging an image, it will generally look best
        with Bicubic (slow) or Bilinear (faster but still looks OK).
        More details can be found in the documentation of OpenCV, please refer to
        http://docs.opencv.org/master/da/d54/group__imgproc__transform.html.
    sizes : tuple of int
        (old_height, old_width, new_height, new_width), if None provided, auto(9)
        will return Area(2) anyway.
​
    Returns
    -------
    int
        interp method from 0 to 4
    """
    if interp == 9:
        if sizes:
            assert len(sizes) == 4
            oh, ow, nh, nw = sizes
            if nh > oh and nw > ow:
                return 2
            elif nh < oh and nw < ow:
                return 3
            else:
                return 1
        else:
            return 2
    if interp == 10:
        return random.randint(0, 4)
    if interp not in (0, 1, 2, 3, 4):
        raise ValueError('Unknown interp method %d' % interp)


def resize_short_within(img, short=512, max_size=1024, mult_base=32, interp=2):
    """
    resizes the short side of the image so the aspect ratio remains the same AND the short
    side matches the convolutional layer for the network
​
    Args:
    -----
    img: np.array
        image you want to resize
    short: int
        the size to reshape the image to
    max_size: int
        the max size of the short side
    mult_base: int
        the size scale to readjust the resizer
    interp: int
        see '_get_interp_method'
    Returns:
    --------
    img: np.array
        the resized array
    """
    h, w, _ = img.shape
    im_size_min, im_size_max = (h, w) if w > h else (w, h)
    scale = float(short) / float(im_size_min)
    if np.round(scale * im_size_max / mult_base) * mult_base > max_size:
        # fit in max_size
        scale = float(np.floor(max_size / mult_base) * mult_base) / float(im_size_max)
    new_w, new_h = (
        int(np.round(w * scale / mult_base) * mult_base),
        int(np.round(h * scale / mult_base) * mult_base)
    )
    img = cv2.resize(img, (new_w, new_h),
                     interpolation=_get_interp_method(interp, (h, w, new_h, new_w)))
    return img


if __name__ == '__main__':

    run()
