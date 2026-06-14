#!/bin/bash
# Script para validar y ejecutar pruebas del proyecto

echo "🎵 Entrenador Musical Pro - Script de Validación"
echo "=================================================="
echo ""

# 1. Verificar que estamos en el directorio correcto
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Error: pubspec.yaml no encontrado"
    echo "Ejecuta este script desde la raíz del proyecto"
    exit 1
fi

echo "✅ Proyecto encontrado"
echo ""

# 2. Obtener dependencias
echo "📦 Obteniendo dependencias..."
flutter pub get
if [ $? -ne 0 ]; then
    echo "❌ Error al obtener dependencias"
    exit 1
fi
echo "✅ Dependencias obtenidas"
echo ""

# 3. Analizar código
echo "🔍 Analizando código..."
flutter analyze
if [ $? -ne 0 ]; then
    echo "⚠️  Se encontraron advertencias de análisis"
fi
echo ""

# 4. Ejecutar tests
echo "🧪 Ejecutando tests..."
flutter test test/core_tests.dart -v
if [ $? -ne 0 ]; then
    echo "❌ Algunos tests fallaron"
    exit 1
fi
echo "✅ Todos los tests pasaron"
echo ""

echo "=================================================="
echo "✅ Validación completada exitosamente"
echo ""
echo "Para ejecutar la app:"
echo "  flutter run"
echo ""
echo "Para ejecutar tests interactivamente:"
echo "  flutter test -v"
echo ""
