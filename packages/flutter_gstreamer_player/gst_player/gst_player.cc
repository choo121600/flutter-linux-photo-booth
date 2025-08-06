#include "gst_player.h"

#include <gst/video/video.h>

#define GstPlayer_GstInit_ProgramName   "gstreamer"
#define GstPlayer_GstInit_Arg1          "/home/1.ogg"

GstPlayer::GstPlayer(const std::vector<std::string>& cmd_arguments) {
  if (cmd_arguments.empty()) {
    char  arg0[] = GstPlayer_GstInit_ProgramName;
    char  arg1[] = GstPlayer_GstInit_Arg1;
    char* argv[] = { &arg0[0], &arg1[0], NULL };
    int   argc   = (int)(sizeof(argv) / sizeof(argv[0])) - 1;
    gst_init(&argc, (char ***)&argv);
  } else {
    // TODO handle this case, pass command line arguments to gstreamer
  }
}

GstPlayer::~GstPlayer() {
  // TODO Should free GStreamers stuff in destructor,
  // but when implemented, flutter complains something about texture
  // when closing application
  // freeGst();
}

void GstPlayer::onVideo(VideoFrameCallback callback) {
  video_callback_ = callback;
}

void GstPlayer::play(const gchar* pipelineString) {
  pipelineString_ = pipelineString;

  // Check and free previous playing GStreamers if any
  if (sink_ != nullptr || pipeline != nullptr) {
    freeGst();
  }

  GError* error = nullptr;
  pipeline = gst_parse_launch(
       pipelineString_.c_str(),
      &error);

  if (error != nullptr) {
    g_print("GStreamer pipeline error: %s\n", error->message);
    g_error_free(error);
    return;
  }

  if (pipeline == nullptr) {
    g_print("Failed to create GStreamer pipeline\n");
    return;
  }

  sink_ = gst_bin_get_by_name(GST_BIN(pipeline), "sink");
  if (sink_ == nullptr) {
    g_print("Failed to find sink element in pipeline\n");
    gst_object_unref(pipeline);
    pipeline = nullptr;
    return;
  }

  gst_app_sink_set_emit_signals(GST_APP_SINK(sink_), TRUE);
  g_signal_connect(sink_, "new-sample", G_CALLBACK(newSample), (gpointer)this);

  GstStateChangeReturn ret = gst_element_set_state(pipeline, GST_STATE_PLAYING);
  if (ret == GST_STATE_CHANGE_FAILURE) {
    g_print("Failed to set pipeline to PLAYING state\n");
    freeGst();
  }
}

void GstPlayer::freeGst(void) {
  if (pipeline != nullptr) {
    gst_element_set_state(pipeline, GST_STATE_NULL);
    gst_object_unref(pipeline);
    pipeline = nullptr;
  }
  if (sink_ != nullptr) {
    gst_object_unref(sink_);
    sink_ = nullptr;
  }
}

GstFlowReturn GstPlayer::newSample(GstAppSink *sink, gpointer gSelf) {
  GstSample* sample = NULL;
  GstMapInfo bufferInfo;

  GstPlayer* self = static_cast<GstPlayer* >(gSelf);
  sample = gst_app_sink_pull_sample(GST_APP_SINK(self->sink_));

  if(sample != NULL) {
    GstBuffer *buffer_ = gst_sample_get_buffer(sample);
    if(buffer_ != NULL) {
      gst_buffer_map(buffer_, &bufferInfo, GST_MAP_READ);

      // Get video width and height
      GstVideoFrame vframe;
      GstVideoInfo video_info;
      GstCaps* sampleCaps = gst_sample_get_caps(sample);
      gst_video_info_from_caps(&video_info, sampleCaps);
      gst_video_frame_map (&vframe, &video_info, buffer_, GST_MAP_READ);

      self->video_callback_(
          (uint8_t*)bufferInfo.data,
          video_info.size,
          video_info.width,
          video_info.height,
          video_info.stride[0]);

      gst_buffer_unmap(buffer_, &bufferInfo);
      gst_video_frame_unmap(&vframe);
    }
    gst_sample_unref(sample);
  }

  return GST_FLOW_OK;
}

GstPlayer* GstPlayers::Get(int32_t id, std::vector<std::string> cmd_arguments) {
  std::lock_guard<std::mutex> lock(mutex_);
  auto [it, added] = players_.try_emplace(id, nullptr);
  if (added) {
    it->second = std::make_unique<GstPlayer>(cmd_arguments);
  }
  return it->second.get();
}

void GstPlayers::Dispose(int32_t id) {
  std::lock_guard<std::mutex> lock(mutex_);
  players_.erase(id);
}
