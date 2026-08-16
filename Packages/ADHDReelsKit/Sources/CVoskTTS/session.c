#include "CVoskTTS.h"

#include <onnxruntime_c_api.h>
#include <stdlib.h>
#include <string.h>

#define ORT (OrtGetApiBase()->GetApi(ORT_API_VERSION))

struct VoskSession {
    OrtEnv *environment;
    OrtSessionOptions *options;
    OrtSession *session;
    OrtMemoryInfo *memory;
};

/// Каждый вызов onnxruntime возвращает OrtStatus: NULL — всё хорошо, иначе объект
/// с текстом ошибки, который надо освободить. Текст нам не нужен: наверху всё равно
/// один исход — модель не поднялась.
static int failed(const OrtApi *ort, OrtStatus *status) {
    if (status == NULL) return 0;
    ort->ReleaseStatus(status);
    return 1;
}

VoskSession *vosk_session_create(const char *path, int threads) {
    const OrtApi *ort = ORT;
    if (ort == NULL) return NULL;

    VoskSession *handle = calloc(1, sizeof(VoskSession));
    if (handle == NULL) return NULL;

    if (failed(ort, ort->CreateEnv(ORT_LOGGING_LEVEL_ERROR, "vosk", &handle->environment))
        || failed(ort, ort->CreateSessionOptions(&handle->options))
        || failed(ort, ort->SetIntraOpNumThreads(handle->options, threads))
        || failed(ort, ort->CreateSession(handle->environment, path, handle->options, &handle->session))
        || failed(ort, ort->CreateCpuMemoryInfo(OrtArenaAllocator, OrtMemTypeDefault, &handle->memory))) {
        vosk_session_destroy(handle);
        return NULL;
    }

    return handle;
}

void vosk_session_destroy(VoskSession *handle) {
    if (handle == NULL) return;

    const OrtApi *ort = ORT;
    if (ort != NULL) {
        if (handle->memory != NULL) ort->ReleaseMemoryInfo(handle->memory);
        if (handle->session != NULL) ort->ReleaseSession(handle->session);
        if (handle->options != NULL) ort->ReleaseSessionOptions(handle->options);
        if (handle->environment != NULL) ort->ReleaseEnv(handle->environment);
    }

    free(handle);
}

/// Сколько всего чисел в выходном тензоре. 0 — если форму узнать не удалось.
static size_t element_count(const OrtApi *ort, OrtValue *value) {
    OrtTensorTypeAndShapeInfo *info = NULL;
    size_t count = 0;

    if (failed(ort, ort->GetTensorTypeAndShape(value, &info))) return 0;
    if (failed(ort, ort->GetTensorShapeElementCount(info, &count))) count = 0;
    ort->ReleaseTensorTypeAndShapeInfo(info);

    return count;
}

/// Данные выходного тензора живут внутри OrtValue и умирают вместе с ним — копируем.
static float *copy_output(const OrtApi *ort, OrtValue *value, size_t *count) {
    float *source = NULL;
    float *result = NULL;

    *count = element_count(ort, value);
    if (*count == 0) return NULL;
    if (failed(ort, ort->GetTensorMutableData(value, (void **)&source))) return NULL;

    result = malloc(sizeof(float) * *count);
    if (result != NULL) memcpy(result, source, sizeof(float) * *count);

    return result;
}

float *vosk_bert_run(VoskSession *handle, const int64_t *ids, int count, int *width) {
    const OrtApi *ort = ORT;
    const char *names[3] = {"input_ids", "attention_mask", "token_type_ids"};
    const char *outputs[1] = {"logits"};
    OrtValue *inputs[3] = {NULL, NULL, NULL};
    OrtValue *output = NULL;
    const void *sources[3];
    int64_t shape[2];
    int64_t *mask = NULL;
    int64_t *types = NULL;
    float *result = NULL;
    size_t total = 0;
    int i = 0;

    *width = 0;
    if (ort == NULL || handle == NULL || count <= 0) return NULL;

    // Фразу отдаём целиком и без паддинга: маска — единицы, сегмент один.
    mask = malloc(sizeof(int64_t) * (size_t)count);
    types = calloc((size_t)count, sizeof(int64_t));
    if (mask == NULL || types == NULL) goto done;
    for (i = 0; i < count; i++) mask[i] = 1;

    shape[0] = 1;
    shape[1] = count;
    sources[0] = ids;
    sources[1] = mask;
    sources[2] = types;

    for (i = 0; i < 3; i++) {
        if (failed(ort, ort->CreateTensorWithDataAsOrtValue(
                handle->memory, (void *)sources[i], sizeof(int64_t) * (size_t)count,
                shape, 2, ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64, &inputs[i]))) goto done;
    }

    if (failed(ort, ort->Run(handle->session, NULL, names,
                             (const OrtValue *const *)inputs, 3, outputs, 1, &output))) goto done;

    result = copy_output(ort, output, &total);
    if (result != NULL) *width = (int)(total / (size_t)count);

done:
    if (output != NULL) ort->ReleaseValue(output);
    for (i = 0; i < 3; i++) {
        if (inputs[i] != NULL) ort->ReleaseValue(inputs[i]);
    }
    free(mask);
    free(types);

    return result;
}

float *vosk_tts_run(VoskSession *handle, const int64_t *phonemes, int frames,
                    const float *bert, int width, const float *scales,
                    int64_t speaker, int *count) {
    const OrtApi *ort = ORT;
    const char *names[5] = {"input", "input_lengths", "scales", "sid", "bert"};
    const char *outputs[1] = {"wav"};
    OrtValue *inputs[5] = {NULL, NULL, NULL, NULL, NULL};
    OrtValue *output = NULL;
    int64_t length = frames;
    int64_t phoneme_shape[3];
    int64_t bert_shape[3];
    int64_t scalar_shape[1] = {1};
    int64_t scales_shape[1] = {3};
    float *result = NULL;
    size_t total = 0;
    int i = 0;

    *count = 0;
    if (ort == NULL || handle == NULL || frames <= 0 || width <= 0) return NULL;

    phoneme_shape[0] = 1;
    phoneme_shape[1] = 5;
    phoneme_shape[2] = frames;

    bert_shape[0] = 1;
    bert_shape[1] = width;
    bert_shape[2] = frames;

    if (failed(ort, ort->CreateTensorWithDataAsOrtValue(
            handle->memory, (void *)phonemes, sizeof(int64_t) * 5 * (size_t)frames,
            phoneme_shape, 3, ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64, &inputs[0]))) goto done;

    if (failed(ort, ort->CreateTensorWithDataAsOrtValue(
            handle->memory, &length, sizeof(int64_t),
            scalar_shape, 1, ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64, &inputs[1]))) goto done;

    if (failed(ort, ort->CreateTensorWithDataAsOrtValue(
            handle->memory, (void *)scales, sizeof(float) * 3,
            scales_shape, 1, ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT, &inputs[2]))) goto done;

    if (failed(ort, ort->CreateTensorWithDataAsOrtValue(
            handle->memory, &speaker, sizeof(int64_t),
            scalar_shape, 1, ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64, &inputs[3]))) goto done;

    if (failed(ort, ort->CreateTensorWithDataAsOrtValue(
            handle->memory, (void *)bert, sizeof(float) * (size_t)width * (size_t)frames,
            bert_shape, 3, ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT, &inputs[4]))) goto done;

    if (failed(ort, ort->Run(handle->session, NULL, names,
                             (const OrtValue *const *)inputs, 5, outputs, 1, &output))) goto done;

    result = copy_output(ort, output, &total);
    if (result != NULL) *count = (int)total;

done:
    if (output != NULL) ort->ReleaseValue(output);
    for (i = 0; i < 5; i++) {
        if (inputs[i] != NULL) ort->ReleaseValue(inputs[i]);
    }

    return result;
}
