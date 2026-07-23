#include "gst_player.h"

#include "include/flutter_gstreamer_player/flutter_gstreamer_player_plugin.h"

#include <flutter_linux/flutter_linux.h>

#include <cstring>
#include <memory>
#include <mutex>
#include <unordered_map>
#include <vector>

#define FLUTTER_GSTREAMER_PLAYER_PLUGIN(obj)                                 \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), flutter_gstreamer_player_plugin_get_type(), \
                              FlutterGstreamerPlayerPlugin))

struct _FlutterGstreamerPlayerPlugin {
  GObject parent_instance;
};

// Latest raw RGBA frame per player. Written on the GStreamer streaming thread
// and read by Dart (via the "getFrame" method) on the platform thread. This
// deliberately avoids Flutter's FlPixelBufferTexture external-texture path,
// which segfaults the engine's compositor on this platform (Ubuntu Frame /
// mesa v3d). Dart renders the frame with RawImage + decodeImageFromPixels.
struct FrameData {
  std::vector<uint8_t> bytes;
  int32_t width = 0;
  int32_t height = 0;
  int64_t seq = 0;
  std::mutex mutex;
};
static std::unordered_map<int32_t, std::unique_ptr<FrameData>> g_frames;

G_DEFINE_TYPE(FlutterGstreamerPlayerPlugin, flutter_gstreamer_player_plugin,
              g_object_get_type())

static void flutter_gstreamer_player_plugin_handle_method_call(
    FlutterGstreamerPlayerPlugin* self, FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  if (strcmp(method, "PlayerRegisterTexture") == 0) {
    const gchar* pipeline =
        fl_value_get_string(fl_value_lookup_string(args, "pipeline"));
    int32_t player_id =
        fl_value_get_int(fl_value_lookup_string(args, "playerId"));

    GstPlayer* gstPlayer = g_players->Get(player_id);

    auto [it, added] = g_frames.try_emplace(player_id, nullptr);
    if (added) {
      it->second = std::make_unique<FrameData>();
      FrameData* frame_data = it->second.get();
      gstPlayer->onVideo([frame_data](uint8_t* frame, uint32_t size,
                                      int32_t width, int32_t height,
                                      int32_t stride) -> void {
        if (frame == nullptr || size == 0 || width <= 0 || height <= 0) {
          return;
        }
        std::lock_guard<std::mutex> lock(frame_data->mutex);
        frame_data->bytes.assign(frame, frame + size);
        frame_data->width = width;
        frame_data->height = height;
        frame_data->seq++;
      });
    }

    gstPlayer->play(pipeline);
    response = FL_METHOD_RESPONSE(
        fl_method_success_response_new(fl_value_new_int(player_id)));
  } else if (strcmp(method, "getFrame") == 0) {
    int32_t player_id =
        fl_value_get_int(fl_value_lookup_string(args, "playerId"));
    // Dart passes the seq it last decoded; we ship pixel bytes only when a
    // newer frame exists, so fast polling never re-transfers a stale frame.
    int64_t since_seq = 0;
    FlValue* since = fl_value_lookup_string(args, "sinceSeq");
    if (since != nullptr && fl_value_get_type(since) == FL_VALUE_TYPE_INT) {
      since_seq = fl_value_get_int(since);
    }
    g_autoptr(FlValue) result = fl_value_new_map();
    auto it = g_frames.find(player_id);
    if (it != g_frames.end()) {
      std::lock_guard<std::mutex> lock(it->second->mutex);
      fl_value_set_string_take(result, "seq",
                               fl_value_new_int(it->second->seq));
      fl_value_set_string_take(result, "width",
                               fl_value_new_int(it->second->width));
      fl_value_set_string_take(result, "height",
                               fl_value_new_int(it->second->height));
      if (it->second->bytes.empty() || it->second->seq == since_seq) {
        fl_value_set_string_take(result, "bytes",
                                 fl_value_new_uint8_list(nullptr, 0));
      } else {
        fl_value_set_string_take(
            result, "bytes",
            fl_value_new_uint8_list(it->second->bytes.data(),
                                    it->second->bytes.size()));
      }
    } else {
      fl_value_set_string_take(result, "seq", fl_value_new_int(0));
      fl_value_set_string_take(result, "width", fl_value_new_int(0));
      fl_value_set_string_take(result, "height", fl_value_new_int(0));
      fl_value_set_string_take(result, "bytes",
                               fl_value_new_uint8_list(nullptr, 0));
    }
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else if (strcmp(method, "dispose") == 0) {
    int32_t player_id =
        fl_value_get_int(fl_value_lookup_string(args, "playerId"));
    g_frames.erase(player_id);
    g_players->Dispose(player_id);
    response = FL_METHOD_RESPONSE(
        fl_method_success_response_new(fl_value_new_bool(true)));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void flutter_gstreamer_player_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(flutter_gstreamer_player_plugin_parent_class)->dispose(object);
}

static void flutter_gstreamer_player_plugin_class_init(
    FlutterGstreamerPlayerPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = flutter_gstreamer_player_plugin_dispose;
}

static void flutter_gstreamer_player_plugin_init(
    FlutterGstreamerPlayerPlugin* self) {}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  FlutterGstreamerPlayerPlugin* plugin =
      FLUTTER_GSTREAMER_PLAYER_PLUGIN(user_data);
  flutter_gstreamer_player_plugin_handle_method_call(plugin, method_call);
}

void flutter_gstreamer_player_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {
  FlutterGstreamerPlayerPlugin* plugin = FLUTTER_GSTREAMER_PLAYER_PLUGIN(
      g_object_new(flutter_gstreamer_player_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "flutter_gstreamer_player", FL_METHOD_CODEC(codec));

  fl_method_channel_set_method_call_handler(
      channel, method_call_cb, g_object_ref(plugin), g_object_unref);

  g_object_unref(plugin);
}
