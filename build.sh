#!/bin/bash

#set -e

## Copy this script inside the kernel directory
KERNEL_DEFCONFIG=cust_defconfig
ANYKERNEL3_DIR=$PWD/AnyKernel3/
FINAL_KERNEL_ZIP=bsdiwala-MiAtoll-$(date '+%Y%m%d').zip
export PATH="$HOME/tools/proton/bin:$PATH"
export ARCH=arm64
export KBUILD_BUILD_HOST=Github-CI
export KBUILD_BUILD_USER=bsdiwala
export KBUILD_COMPILER_STRING="$($HOME/tools/proton/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"

if ! [ -d "$HOME/proton" ]; then
echo "Proton clang not found! Cloning..."
if ! git clone -q https://github.com/kdrag0n/proton-clang --depth=1 --single-branch ~/proton; then
echo "Cloning failed! Aborting..."
exit 1
fi
fi


# Speed up build process
MAKE="./makeparallel"

BUILD_START=$(date +"%s")

# Clean build always lol
echo "**** Cleaning ****"
mkdir -p out
make O=out clean
make mrproper

echo "**** Kernel defconfig is set to $KERNEL_DEFCONFIG ****"
echo -e "***************************************************"
echo "****          BUILDING KERNEL          ****"
echo -e "***************************************************"
make $KERNEL_DEFCONFIG O=out
make -j$(nproc --all) O=out \
                      ARCH=arm64 \
                      CC=clang \
		      CROSS_COMPILE=aarch64-linux-gnu- \
                      CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
                      LD=ld.lld \
                      LLVM=1 \
                      LLVM_IAS=1

echo "**** Verify Image.gz, dtbo.img & dtb ****"
ls $PWD/out/arch/arm64/boot/Image.gz
ls $PWD/out/arch/arm64/boot/dtbo.img
ls $PWD/out/arch/arm64/boot/dts/qcom/cust-atoll-ab.dtb

# Anykernel 3 time!!
echo "**** Verifying AnyKernel3 Directory ****"
ls $ANYKERNEL3_DIR
echo "**** Removing leftovers ****"
rm -rf $ANYKERNEL3_DIR/Image.gz
rm -rf $ANYKERNEL3_DIR/dtbo.img
rm -rf $ANYKERNEL3_DIR/dtb
rm -rf $ANYKERNEL3_DIR/$FINAL_KERNEL_ZIP

echo "**** Copying Image.gz , dtbo.img & dtb ****"
cp $PWD/out/arch/arm64/boot/Image.gz $ANYKERNEL3_DIR/
cp $PWD/out/arch/arm64/boot/dtbo.img $ANYKERNEL3_DIR/
cp $PWD/out/arch/arm64/boot/dts/qcom/cust-atoll-ab.dtb $ANYKERNEL3_DIR/dtb

echo "**** Time to zip up! ****"
cd $ANYKERNEL3_DIR/
zip -r9 "../$FINAL_KERNEL_ZIP" * -x README $FINAL_KERNEL_ZIP
MD5CHECK=$(md5sum "../$FINAL_KERNEL_ZIP" | cut -d' ' -f1)

echo "**** Done, here is your MD5 ****"
cd ..
rm -rf $ANYKERNEL3_DIR/$FINAL_KERNEL_ZIP
rm -rf $ANYKERNEL3_DIR/Image.gz
rm -rf $ANYKERNEL3_DIR/dtbo.img
rm -rf $ANYKERNEL3_DIR/dtb
rm -rf out/
md5sum $FINAL_KERNEL_ZIP

BUILD_END=$(date +"%s")
DIFF=$(($BUILD_END - $BUILD_START))
post_msg="Build completed in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s)
MD5 Checksum: $MD5CHECK"
curl -v -F chat_id=$chat_id -F document=@$FINAL_KERNEL_ZIP -F caption="$post_msg" https://api.telegram.org/bot$token/sendDocument
