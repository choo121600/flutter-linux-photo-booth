#ifndef VIDEO_OUTLET_H_
#define VIDEO_OUTLET_H_

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

struct _VideoOutletClass {
  FlPixelBufferTextureClass parent_class;
};

struct VideoOutletPrivate {
  int64_t texture_id = 0;
  uint8_t* buffer = nullptr;
  int32_t video_width = 0;
  int32_t video_height = 0;
  size_t buffer_size = 0;
  GMutex mutex;
  FlTextureRegistrar* registrar = nullptr;
  gboolean frame_pending = FALSE;
};

G_DECLARE_DERIVABLE_TYPE(VideoOutlet, video_outlet, MY_OPENGL, VIDEO_OUTLET,
                         FlPixelBufferTexture)

G_DEFINE_TYPE_WITH_CODE(VideoOutlet, video_outlet, fl_pixel_buffer_texture_get_type(), G_ADD_PRIVATE(VideoOutlet))

static VideoOutlet* video_outlet_new() {
  return MY_OPENGL_VIDEO_OUTLET(g_object_new(video_outlet_get_type(), nullptr));
}

static gboolean video_outlet_copy_pixels(
    FlPixelBufferTexture* texture, const uint8_t** out_buffer, uint32_t* width,
    uint32_t* height, GError** error) {
  auto video_outlet_private = (VideoOutletPrivate*) video_outlet_get_instance_private(MY_OPENGL_VIDEO_OUTLET(texture));
  g_mutex_lock(&video_outlet_private->mutex);
  if (video_outlet_private->buffer == nullptr ||
      video_outlet_private->video_width <= 0 ||
      video_outlet_private->video_height <= 0) {
    g_mutex_unlock(&video_outlet_private->mutex);
    return FALSE;
  }
  *out_buffer = video_outlet_private->buffer;
  *width = video_outlet_private->video_width;
  *height = video_outlet_private->video_height;
  g_mutex_unlock(&video_outlet_private->mutex);
  return TRUE;
}

static void video_outlet_class_init(VideoOutletClass* klass) {
  FL_PIXEL_BUFFER_TEXTURE_CLASS(klass)->copy_pixels = video_outlet_copy_pixels;
}

static void video_outlet_init(VideoOutlet* self) {
  auto video_outlet_private = (VideoOutletPrivate*) video_outlet_get_instance_private(self);
  g_mutex_init(&video_outlet_private->mutex);
}

#endif
