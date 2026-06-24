/*
  ESP32-CAM Basic - Camera Stream Server
  Use this code for your 3 regular camera modules.
  Each one will host a web server at /snapshot and /stream.

  Board: AI Thinker ESP32-CAM
  Flash mode: QIO
  Upload speed: 115200
  IMPORTANT: Set GPIO0 to LOW (connect to GND) before uploading.
             Remove the wire after upload, then press RESET.
*/

#include "esp_camera.h"
#include <WiFi.h>
#include "esp_http_server.h"

// ===== CHANGE THESE =====
const char* ssid     = "arifidris";
const char* password = "arif1412";

// Fixed IP — change last number for each camera (101, 102, 103)
IPAddress local_IP(192, 168, 1, 103); // Camera 2 = .101 | Camera 3 = .102 | Camera 4 = .103
IPAddress gateway(192, 168, 1, 1);    // your router IP — run ipconfig on PC to check
IPAddress subnet(255, 255, 255, 0);
// ========================

// Camera pins for AI-Thinker ESP32-CAM (do not change)
#define PWDN_GPIO_NUM   32
#define RESET_GPIO_NUM  -1
#define XCLK_GPIO_NUM    0
#define SIOD_GPIO_NUM   26
#define SIOC_GPIO_NUM   27
#define Y9_GPIO_NUM     35
#define Y8_GPIO_NUM     34
#define Y7_GPIO_NUM     39
#define Y6_GPIO_NUM     36
#define Y5_GPIO_NUM     21
#define Y4_GPIO_NUM     19
#define Y3_GPIO_NUM     18
#define Y2_GPIO_NUM      5
#define VSYNC_GPIO_NUM  25
#define HREF_GPIO_NUM   23
#define PCLK_GPIO_NUM   22

httpd_handle_t server_httpd = NULL;

// ---------- /snapshot endpoint (returns a single JPEG frame) ----------
esp_err_t snapshot_handler(httpd_req_t *req) {
  camera_fb_t *fb = esp_camera_fb_get();
  if (!fb) {
    httpd_resp_send_500(req);
    return ESP_FAIL;
  }

  httpd_resp_set_type(req, "image/jpeg");
  httpd_resp_set_hdr(req, "Access-Control-Allow-Origin", "*");
  httpd_resp_set_hdr(req, "Connection", "close"); // free socket after each request
  httpd_resp_send(req, (const char *)fb->buf, fb->len);
  esp_camera_fb_return(fb);
  return ESP_OK;
}

// ---------- /stream endpoint (MJPEG stream, for browser testing) ----------
#define BOUNDARY "esp32boundary"
static const char* STREAM_CONTENT = "multipart/x-mixed-replace;boundary=" BOUNDARY;
static const char* BOUNDARY_STR   = "\r\n--" BOUNDARY "\r\n";
static const char* PART_HEADER    = "Content-Type: image/jpeg\r\nContent-Length: %u\r\n\r\n";

esp_err_t stream_handler(httpd_req_t *req) {
  char part_buf[64];
  httpd_resp_set_type(req, STREAM_CONTENT);
  httpd_resp_set_hdr(req, "Access-Control-Allow-Origin", "*");

  while (true) {
    camera_fb_t *fb = esp_camera_fb_get();
    if (!fb) continue;

    httpd_resp_send_chunk(req, BOUNDARY_STR, strlen(BOUNDARY_STR));
    size_t hlen = snprintf(part_buf, sizeof(part_buf), PART_HEADER, fb->len);
    httpd_resp_send_chunk(req, part_buf, hlen);
    httpd_resp_send_chunk(req, (const char *)fb->buf, fb->len);

    esp_camera_fb_return(fb);

    if (req->ignore_sess_ctx_changes) break; // client disconnected
  }
  return ESP_OK;
}

void startServer() {
  httpd_config_t config  = HTTPD_DEFAULT_CONFIG();
  config.server_port     = 80;
  config.lru_purge_enable = true; // auto-close old stuck connections

  httpd_uri_t snapshot_uri = {
    .uri     = "/snapshot",
    .method  = HTTP_GET,
    .handler = snapshot_handler,
  };

  httpd_uri_t stream_uri = {
    .uri     = "/stream",
    .method  = HTTP_GET,
    .handler = stream_handler,
  };

  if (httpd_start(&server_httpd, &config) == ESP_OK) {
    httpd_register_uri_handler(server_httpd, &snapshot_uri);
    httpd_register_uri_handler(server_httpd, &stream_uri);
    Serial.println("Server started.");
  }
}

void setup() {
  Serial.begin(115200);
  Serial.println("\nStarting ESP32-CAM Basic...");

  // Init camera
  camera_config_t config;
  config.ledc_channel  = LEDC_CHANNEL_0;
  config.ledc_timer    = LEDC_TIMER_0;
  config.pin_d0        = Y2_GPIO_NUM;
  config.pin_d1        = Y3_GPIO_NUM;
  config.pin_d2        = Y4_GPIO_NUM;
  config.pin_d3        = Y5_GPIO_NUM;
  config.pin_d4        = Y6_GPIO_NUM;
  config.pin_d5        = Y7_GPIO_NUM;
  config.pin_d6        = Y8_GPIO_NUM;
  config.pin_d7        = Y9_GPIO_NUM;
  config.pin_xclk      = XCLK_GPIO_NUM;
  config.pin_pclk      = PCLK_GPIO_NUM;
  config.pin_vsync     = VSYNC_GPIO_NUM;
  config.pin_href      = HREF_GPIO_NUM;
  config.pin_sscb_sda  = SIOD_GPIO_NUM;
  config.pin_sscb_scl  = SIOC_GPIO_NUM;
  config.pin_pwdn      = PWDN_GPIO_NUM;
  config.pin_reset     = RESET_GPIO_NUM;
  config.xclk_freq_hz  = 20000000;
  config.pixel_format  = PIXFORMAT_JPEG;
  config.frame_size    = FRAMESIZE_QVGA; // 320x240 — good balance of speed/quality
  config.jpeg_quality  = 12;            // 0=best, 63=worst
  config.fb_count      = 1;

  if (esp_camera_init(&config) != ESP_OK) {
    Serial.println("Camera init FAILED! Check wiring.");
    return;
  }
  Serial.println("Camera OK.");

  // Connect to WiFi with fixed IP
  WiFi.config(local_IP, gateway, subnet);
  WiFi.begin(ssid, password);
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println("\nWiFi connected!");
  Serial.println("=================================");
  Serial.print("Snapshot URL: http://");
  Serial.print(WiFi.localIP());
  Serial.println("/snapshot");
  Serial.print("Stream URL:   http://");
  Serial.print(WiFi.localIP());
  Serial.println("/stream");
  Serial.println("=================================");

  startServer();
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi lost, reconnecting...");
    WiFi.begin(ssid, password);
    while (WiFi.status() != WL_CONNECTED) {
      delay(500);
      Serial.print(".");
    }
    Serial.println("\nReconnected: " + WiFi.localIP().toString());
  }
  delay(5000);
}
