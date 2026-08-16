#pragma once

#include <stdint.h>

// C API onnxruntime — это структура указателей на функции, полученная через
// OrtGetApiBase(). Дёргать её из Swift можно, но каждый вызов превращается в три
// строки разыменований и проверку OrtStatus. Держим всю церемонию здесь, наружу
// отдаём две функции — ровно те два графа, которые нужны vosk-tts.

typedef struct VoskSession VoskSession;

/// NULL, если модель не открылась.
VoskSession *vosk_session_create(const char *path, int threads);
void vosk_session_destroy(VoskSession *session);

/// ruBERT: идентификаторы токенов длиной `count` → `count` × `*width` вещественных.
/// Маску внимания и типы сегментов заполняем сами: у нас всегда одна фраза целиком.
/// Возвращает malloc'нутый буфер, освобождать вызывающему.
float *vosk_bert_run(VoskSession *session, const int64_t *ids, int count, int *width);

/// VITS: `phonemes` — пять потоков по `frames` значений подряд, `bert` — `width`
/// строк по `frames`. Возвращает malloc'нутые сэмплы, их число в `*count`.
float *vosk_tts_run(VoskSession *session, const int64_t *phonemes, int frames,
                    const float *bert, int width, const float *scales,
                    int64_t speaker, int *count);
