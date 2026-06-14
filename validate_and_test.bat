@echo off
REM Script para validar y ejecutar pruebas del proyecto en Windows

echo.
echo 🎵 Entrenador Musical Pro - Script de Validacion (Windows)
echo ===========================================================
echo.

REM 1. Verificar que estamos en el directorio correcto
if not exist "pubspec.yaml" (
    echo ❌ Error: pubspec.yaml no encontrado
    echo Ejecuta este script desde la raiz del proyecto
    pause
    exit /b 1
)

echo ✅ Proyecto encontrado
echo.

REM 2. Obtener dependencias
echo 📦 Obteniendo dependencias...
call flutter pub get
if errorlevel 1 (
    echo ❌ Error al obtener dependencias
    pause
    exit /b 1
)
echo ✅ Dependencias obtenidas
echo.

REM 3. Analizar código
echo 🔍 Analizando codigo...
call flutter analyze
if errorlevel 1 (
    echo ⚠️  Se encontraron advertencias de analisis
)
echo.

REM 4. Ejecutar tests
echo 🧪 Ejecutando tests unitarios del core...
call flutter test test/core_tests.dart -v
if errorlevel 1 (
    echo ❌ Algunos tests fallaron
    pause
    exit /b 1
)
echo ✅ Todos los tests pasaron
echo.

echo ===========================================================
echo ✅ Validacion completada exitosamente
echo.
echo Para ejecutar la app:
echo   flutter run
echo.
echo Para ejecutar widget tests:
echo   flutter test test/widget_test.dart
echo.
echo Para ejecutar todos los tests:
echo   flutter test
echo.
pause
