#pragma once

// Заголовок лежит внутри xcframework'а, и модуля у него нет: статическую
// библиотеку Swift напрямую не импортирует. Эта обёртка и есть модуль.
#include <sherpa-onnx/c-api/c-api.h>
