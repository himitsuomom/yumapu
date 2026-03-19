#!/bin/bash
# setup_and_build.sh
# Yu-Map: 完全なビルドとテスト実行スクリプト

set -e  # Exit on error

echo "============================================"
echo "Yu-Map: Complete Setup and Build Script"
echo "============================================"
echo ""

# Color output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Flutter is not installed or not in PATH${NC}"
    echo "Please install Flutter from: https://flutter.dev/docs/get-started/install"
    exit 1
fi

echo -e "${GREEN}✓${NC} Flutter found: $(flutter --version | head -1)"
echo ""

# Step 1: Dependencies
echo -e "${YELLOW}Step 1: Installing dependencies...${NC}"
flutter pub get
echo -e "${GREEN}✓ Dependencies installed${NC}"
echo ""

# Step 2: Clean previous builds
echo -e "${YELLOW}Step 2: Cleaning previous builds...${NC}"
flutter clean
rm -rf lib/gen_l10n/ || true
echo -e "${GREEN}✓ Cleaned${NC}"
echo ""

# Step 3: Code generation
echo -e "${YELLOW}Step 3: Generating code...${NC}"
flutter gen-l10n
echo -e "${GREEN}✓ L10n generated${NC}"

flutter pub run build_runner build --delete-conflicting-outputs
echo -e "${GREEN}✓ Build runner completed${NC}"
echo ""

# Step 4: Analysis
echo -e "${YELLOW}Step 4: Analyzing code quality...${NC}"
flutter analyze
echo -e "${GREEN}✓ Code analysis passed${NC}"
echo ""

# Step 5: Testing
echo -e "${YELLOW}Step 5: Running tests...${NC}"
flutter test test/facility_service_test.dart --concurrency=1
echo -e "${GREEN}✓ Tests passed${NC}"
echo ""

# Step 6: Build
echo -e "${YELLOW}Step 6: Building APK for testing...${NC}"
flutter build apk --debug
echo -e "${GREEN}✓ APK built successfully${NC}"
echo ""

echo -e "${GREEN}============================================"
echo "✓ All steps completed successfully!"
echo "============================================${NC}"
echo ""
echo "Generated APK location:"
echo "  build/app/outputs/flutter-apk/app-debug.apk"
echo ""
