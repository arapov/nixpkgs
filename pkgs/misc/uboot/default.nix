{ stdenv
, lib
, fetchurl
, fetchFromGitHub
, bc
, bison
, dtc
, flex
, openssl
, swig
, armTrustedFirmwareAllwinner
, armTrustedFirmwareRK3328
, armTrustedFirmwareRK3399
, armTrustedFirmwareS905
, firmwareOdroidC2
, firmwareOdroidC4
, buildPackages
}:

let
  defaultVersion = "2021.01";
  defaultSrc = fetchurl {
    url = "ftp://ftp.denx.de/pub/u-boot/u-boot-${defaultVersion}.tar.bz2";
    sha256 = "0m04glv9kn3bhs62sn675w60wkrl4m3a4hnbnnw67s3l198y21xl";
  };
  buildUBoot = {
    version ? null
  , src ? null
  , filesToInstall
  , installDir ? "$out"
  , defconfig
  , extraConfig ? ""
  , extraPatches ? []
  , extraMakeFlags ? []
  , extraMeta ? {}
  , ... } @ args: stdenv.mkDerivation ({
    pname = "uboot-${defconfig}";

    version = if src == null then defaultVersion else version;

    src = if src == null then defaultSrc else src;

    patches = [
      ./0001-configs-rpi-allow-for-bigger-kernels.patch
    ] ++ extraPatches;

    postPatch = ''
      patchShebangs tools
      patchShebangs arch/arm/mach-rockchip
    '';

    nativeBuildInputs = [
      bc
      bison
      dtc
      flex
      openssl
      (buildPackages.python3.withPackages (p: [
        p.libfdt
        p.setuptools # for pkg_resources
      ]))
      swig
    ];
    depsBuildBuild = [ buildPackages.stdenv.cc ];

    hardeningDisable = [ "all" ];

    makeFlags = [
      "DTC=dtc"
      "CROSS_COMPILE=${stdenv.cc.targetPrefix}"
    ] ++ extraMakeFlags;

    passAsFile = [ "extraConfig" ];

    configurePhase = ''
      runHook preConfigure

      make ${defconfig}

      cat $extraConfigPath >> .config

      runHook postConfigure
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p ${installDir}
      cp ${lib.concatStringsSep " " filesToInstall} ${installDir}

      runHook postInstall
    '';

    # make[2]: *** No rule to make target 'lib/efi_loader/helloworld.efi', needed by '__build'.  Stop.
    enableParallelBuilding = false;

    dontStrip = true;

    meta = with lib; {
      homepage = "http://www.denx.de/wiki/U-Boot/";
      description = "Boot loader for embedded systems";
      license = licenses.gpl2;
      maintainers = with maintainers; [ dezgeg samueldr lopsided98 ];
    } // extraMeta;
  } // removeAttrs args [ "extraMeta" ]);

in {
  inherit buildUBoot;

  ubootTools = buildUBoot {
    defconfig = "tools-only_defconfig";
    installDir = "$out/bin";
    hardeningDisable = [];
    dontStrip = false;
    extraMeta.platforms = lib.platforms.linux;
    extraMakeFlags = [ "HOST_TOOLS_ALL=y" "CROSS_BUILD_TOOLS=1" "NO_SDL=1" "tools" ];
    filesToInstall = [
      "tools/dumpimage"
      "tools/fdtgrep"
      "tools/kwboot"
      "tools/mkenvimage"
      "tools/mkimage"
    ];
  };

  ubootA20OlinuxinoLime = buildUBoot {
    defconfig = "A20-OLinuXino-Lime_defconfig";
    extraMeta.platforms = ["armv7l-linux"];
    filesToInstall = ["u-boot-sunxi-with-spl.bin"];
  };

  ubootAmx335xEVM = buildUBoot {
    defconfig = "am335x_evm_defconfig";
    extraMeta.platforms = ["armv7l-linux"];
    filesToInstall = ["MLO" "u-boot.img"];
  };

  ubootBananaPi = buildUBoot {
    defconfig = "Bananapi_defconfig";
    extraMeta.platforms = ["armv7l-linux"];
    filesToInstall = ["u-boot-sunxi-with-spl.bin"];
  };

  ubootBananaPim3 = buildUBoot {
    defconfig = "Sinovoip_BPI_M3_defconfig";
    extraMeta.platforms = ["armv7l-linux"];
    filesToInstall = ["u-boot-sunxi-with-spl.bin"];
  };

  ubootBananaPim64 = buildUBoot {
    defconfig = "bananapi_m64_defconfig";
    extraMeta.platforms = ["aarch64-linux"];
    BL31 = "${armTrustedFirmwareAllwinner}/bl31.bin";
    filesToInstall = ["u-boot-sunxi-with-spl.bin"];
  };

  # http://git.denx.de/?p=u-boot.git;a=blob;f=board/solidrun/clearfog/README;hb=refs/heads/master
  ubootClearfog = buildUBoot {
    defconfig = "clearfog_defconfig";
    extraMeta.platforms = ["armv7l-linux"];
    filesToInstall = ["u-boot-spl.kwb"];
  };

  ubootGuruplug = buildUBoot {
    defconfig = "guruplug_defconfig";
    extraMeta.platforms = ["armv5tel-linux"];
    filesToInstall = ["u-boot.bin"];
  };

  ubootJetsonTK1 = buildUBoot {
    defconfig = "jetson-tk1_defconfig";
    extraMeta.platforms = ["armv7l-linux"];
    filesToInstall = ["u-boot" "u-boot.dtb" "u-boot-dtb-tegra.bin" "u-boot-nodtb-tegra.bin"];
    # tegra-uboot-flasher expects this exact directory layout, sigh...
    postInstall = ''
      mkdir -p $out/spl
      cp spl/u-boot-spl $out/spl/
    '';
  };

  ubootNanoPCT4 = buildUBoot rec {
    rkbin = fetchFromGitHub {
      owner = "armbian";
      repo = "rkbin";
      rev = "3bd0321cae5ef881a6005fb470009ad5a5d1462d";
      sha256 = "09r4dzxsbs3pff4sh70qnyp30s3rc7pkc46v1m3152s7jqjasp31";
    };

    defconfig = "nanopc-t4-rk3399_defconfig";

    extraMeta = {
      platforms = ["aarch64-linux"];
      license = lib.licenses.unfreeRedistributableFirmware;
    };
    BL31="${armTrustedFirmwareRK3399}/bl31.elf";
    filesToInstall = ["u-boot.itb" "idbloader.img"];
    postBuild = ''
      ./tools/mkimage -n rk3399 -T rksd -d ${rkbin}/rk33/rk3399_ddr_800MHz_v1.24.bin idbloader.img
      cat ${rkbin}/rk33/rk3399_miniloader_v1.19.bin >> idbloader.img
    '';
  };

  ubootNovena = buildUBoot {
    defconfig = "novena_defconfig";
    extraMeta.platforms = ["armv7l-linux"];
    filesToInstall = ["u-boot-dtb.img" "SPL"];
  };

  ubootOdroidC2 = buildUBoot {
    defconfig = "odroid-c2_defconfig";

    postBuild = ''
      # BL301 image needs at least 64 bytes of padding after it to place
      # signing headers (with amlbootsig)
      truncate -s 64 bl301.padding.bin
      cat ${firmwareOdroidC2}/bl301.bin bl301.padding.bin > bl301.padded.bin

      # The downstream fip_create tool adds a custom TOC entry with UUID
      # AABBCCDD-ABCD-EFEF-ABCD-12345678ABCD for the BL301 image. It turns out
      # that the firmware blob does not actually care about UUIDs, only the
      # order the images appear in the file. Because fiptool does not know
      # about the BL301 UUID, we would have to use the --blob option, which adds
      # the image to the end of the file, causing the boot to fail. Instead, we
      # take advantage of the fact that UUIDs are ignored and just put the
      # images in the right order with the wrong UUIDs. In the command below,
      # --tb-fw is really --scp-fw and --scp-fw is the BL301 image.
      #
      # See https://github.com/afaerber/meson-tools/issues/3 for more
      # information.
      ${buildPackages.armTrustedFirmwareTools}/bin/fiptool create \
        --align 0x4000 \
        --tb-fw ${firmwareOdroidC2}/bl30.bin \
        --scp-fw bl301.padded.bin \
        --soc-fw ${armTrustedFirmwareS905}/bl31.bin \
        --nt-fw u-boot.bin \
        fip.bin
      cat ${firmwareOdroidC2}/bl2.package fip.bin > boot_new.bin
      ${buildPackages.meson-tools}/bin/amlbootsig boot_new.bin u-boot.img

      dd if=u-boot.img of=u-boot.bin bs=512 skip=96
    '';

    filesToInstall = [
      "u-boot.bin"
      "${firmwareOdroidC2}/sd_fusing.sh" "${firmwareOdroidC2}/bl1.bin.hardkernel"
    ];
    extraMeta.platforms = ["aarch64-linux"];
  };

  ubootOdroidC4 = buildUBoot {
    defconfig = "odroid-c4_defconfig";

    postBuild = ''
      ${buildPackages.meson64-tools}/bin/pkg --type bl30 --output bl30_new.bin \
        ${firmwareOdroidC4}/bl30.bin ${firmwareOdroidC4}/bl301.bin
      ${buildPackages.meson64-tools}/bin/pkg --type bl2 --output bl2_new.bin \
        ${firmwareOdroidC4}/bl2.bin ${firmwareOdroidC4}/acs.bin

      ${buildPackages.meson64-tools}/bin/bl30sig --input bl30_new.bin \
        --output bl30_new.bin.g12a.enc --level v3
      ${buildPackages.meson64-tools}/bin/bl3sig --input  bl30_new.bin.g12a.enc \
        --output bl30_new.bin.enc --level v3 --type bl30
      ${buildPackages.meson64-tools}/bin/bl3sig --input ${firmwareOdroidC4}/bl31.img \
        --output bl31.img.enc --level v3 --type bl31
      ${buildPackages.meson64-tools}/bin/bl3sig --input u-boot.bin --compress lz4 \
        --output bl33.bin.enc --level v3 --type bl33 --compress lz4
      ${buildPackages.meson64-tools}/bin/bl2sig --input bl2_new.bin \
        --output bl2.n.bin.sig

      ${buildPackages.meson64-tools}/bin/bootmk --output u-boot.bin \
        --bl2 bl2.n.bin.sig --bl30 bl30_new.bin.enc --bl31 bl31.img.enc --bl33 bl33.bin.enc \
        --ddrfw1 ${firmwareOdroidC4}/ddr4_1d.fw \
        --ddrfw2 ${firmwareOdroidC4}/ddr4_2d.fw \
        --ddrfw3 ${firmwareOdroidC4}/ddr3_1d.fw \
        --ddrfw4 ${firmwareOdroidC4}/piei.fw \
        --ddrfw5 ${firmwareOdroidC4}/lpddr4_1d.fw \
        --ddrfw6 ${firmwareOdroidC4}/lpddr4_2d.fw \
        --ddrfw7 ${firmwareOdroidC4}/diag_lpddr4.fw \
        --ddrfw8 ${firmwareOdroidC4}/aml_ddr.fw \
        --ddrfw9 ${firmwareOdroidC4}/lpddr3_1d.fw \
        --level v3
    '';

    filesToInstall = [ "u-boot.bin" "${firmwareOdroidC4}/sd_fusing.sh"];
    extraMeta.platforms = ["aarch64-linux"];
  };

  ubootOdroidXU3 = buildUBoot {
    defconfig = "odroid-xu3_defconfig";
    extraMeta.platforms = ["armv7l-linux"];
    filesToInstall = ["u-boot-dtb.bin"];
  };

  ubootOrangePiPc = buildUBoot {
    defconfig = "orangepi_pc_defconfig";
    extraMeta.platforms = ["armv7l-linux"];
    filesToInstall = ["u-boot-sunxi-with-spl.bin"];
  };

  ubootOrangePiZeroPlus2H5 = buildUBoot {
    defconfig = "orangepi_zero_plus2_defconfig";
    extraMeta.platforms = ["aarch64-linux"];
    BL31 = "${armTrustedFirmwareAllwinner}/bl31.bin";
    filesToInstall = ["u-boot-sunxi-with-spl.bin"];
  };

  ubootOrangePiZero = buildUBoot {
    defconfig = "orangepi_zero_defconfig";
    extraMeta.platforms = ["armv7l-linux"];
    filesToInstall = ["u-boot-sunxi-with-spl.bin"];
  };

  ubootPcduino3Nano = buildUBoot {
    defconfig = "Linksprite_pcDuino3_Nano_defconfig";
    extraMeta.platforms = ["armv7l-linux"];
    filesToInstall = ["u-boot-sunxi-with-spl.bin"];
  };

  ubootPine64 = buildUBoot {
    defconfig = "pine64_plus_defconfig";
    extraMeta.platforms = ["aarch64-linux"];
    BL31 = "${armTrustedFirmwareAllwinner}/bl31.bin";
    filesToInstall = ["u-boot-sunxi-with-spl.bin"];
  };

  ubootPine64LTS = buildUBoot {
    defconfig = "pine64-lts_defconfig";
    extraMeta.platforms = ["aarch64-linux"];
    BL31 = "${armTrustedFirmwareAllwinner}/bl31.bin";
    filesToInstall = ["u-boot-sunxi-with-spl.bin"];
  };

  ubootPinebook = buildUBoot {
    defconfig = "pinebook_defconfig";
    extraMeta.platforms = ["aarch64-linux"];
    BL31 = "${armTrustedFirmwareAllwinner}/bl31.bin";
    filesToInstall = ["u-boot-sunxi-with-spl.bin"];
  };

  ubootPinebookPro = buildUBoot {
    defconfig = "pinebook-pro-rk3399_defconfig";
    extraMeta.platforms = ["aarch64-linux"];
    BL31 = "${armTrustedFirmwareRK3399}/bl31.elf";
    filesToInstall = [ "u-boot.itb" "idbloader.img"];
  };

  ubootQemuAarch64 = buildUBoot {
    defconfig = "qemu_arm64_defconfig";
    extraMeta.platforms = ["aarch64-linux"];
    filesToInstall = ["u-boot.bin"];
  };

  ubootQemuArm = buildUBoot {
    defconfig = "qemu_arm_defconfig";
    extraMeta.platforms = ["armv7l-linux"];
    filesToInstall = ["u-boot.bin"];
  };

  ubootRaspberryPi = buildUBoot {
    defconfig = "rpi_defconfig";
    extraMeta.platforms = ["armv6l-linux"];
    filesToInstall = ["u-boot.bin"];
  };

  ubootRaspberryPi2 = buildUBoot {
    defconfig = "rpi_2_defconfig";
    extraMeta.platforms = ["armv7l-linux"];
    filesToInstall = ["u-boot.bin"];
  };

  ubootRaspberryPi3_32bit = buildUBoot {
    defconfig = "rpi_3_32b_defconfig";
    extraMeta.platforms = ["armv7l-linux"];
    filesToInstall = ["u-boot.bin"];
  };

  ubootRaspberryPi3_64bit = buildUBoot {
    defconfig = "rpi_3_defconfig";
    extraMeta.platforms = ["aarch64-linux"];
    filesToInstall = ["u-boot.bin"];
  };

  ubootRaspberryPi4_32bit = buildUBoot {
    defconfig = "rpi_4_32b_defconfig";
    extraMeta.platforms = ["armv7l-linux"];
    filesToInstall = ["u-boot.bin"];
  };

  ubootRaspberryPi4_64bit = buildUBoot {
    defconfig = "rpi_4_defconfig";
    extraMeta.platforms = ["aarch64-linux"];
    filesToInstall = ["u-boot.bin"];
  };

  ubootRaspberryPiZero = buildUBoot {
    defconfig = "rpi_0_w_defconfig";
    extraMeta.platforms = ["armv6l-linux"];
    filesToInstall = ["u-boot.bin"];
  };

  ubootRock64 = let
    rkbin = fetchFromGitHub {
      owner = "ayufan-rock64";
      repo = "rkbin";
      rev = "f79a708978232a2b6b06c2e4173c5314559e0d3a";
      sha256 = "0h7xm4ck3p3380c6bqm5ixrkxwcx6z5vysqdwvfa7gcqx5d6x5zz";
    };
  in buildUBoot {
    extraMakeFlags = [ "all" "u-boot.itb" ];
    defconfig = "rock64-rk3328_defconfig";
    extraMeta = {
      platforms = [ "aarch64-linux" ];
      license = lib.licenses.unfreeRedistributableFirmware;
    };
    BL31="${armTrustedFirmwareRK3328}/bl31.elf";
    filesToInstall = [ "u-boot.itb" "idbloader.img"];
    # Derive MAC address from cpuid
    # Submitted upstream: https://patchwork.ozlabs.org/patch/1203686/
    extraConfig = ''
      CONFIG_MISC_INIT_R=y
    '';
    # Close to being blob free, but the U-Boot TPL causes random memory
    # corruption
    postBuild = ''
      ./tools/mkimage -n rk3328 -T rksd -d ${rkbin}/rk33/rk3328_ddr_786MHz_v1.13.bin idbloader.img
      cat spl/u-boot-spl.bin >> idbloader.img
    '';
  };

  ubootRockPro64 = buildUBoot {
    extraMakeFlags = [ "all" "u-boot.itb" ];
    defconfig = "rockpro64-rk3399_defconfig";
    extraMeta.platforms = ["aarch64-linux"];
    BL31="${armTrustedFirmwareRK3399}/bl31.elf";
    filesToInstall = [ "u-boot.itb" "idbloader.img"];
  };

  ubootROCPCRK3399 = buildUBoot {
    defconfig = "roc-pc-rk3399_defconfig";
    extraMeta.platforms = ["aarch64-linux"];
    filesToInstall = [ "spl/u-boot-spl.bin" "u-boot.itb" "idbloader.img"];
    BL31 = "${armTrustedFirmwareRK3399}/bl31.elf";
  };

  ubootSheevaplug = buildUBoot {
    defconfig = "sheevaplug_defconfig";
    extraMeta.platforms = ["armv5tel-linux"];
    filesToInstall = ["u-boot.kwb"];
  };

  ubootSopine = buildUBoot {
    defconfig = "sopine_baseboard_defconfig";
    extraMeta.platforms = ["aarch64-linux"];
    BL31 = "${armTrustedFirmwareAllwinner}/bl31.bin";
    filesToInstall = ["u-boot-sunxi-with-spl.bin"];
  };

  ubootUtilite = buildUBoot {
    defconfig = "cm_fx6_defconfig";
    extraMeta.platforms = ["armv7l-linux"];
    filesToInstall = ["u-boot-with-nand-spl.imx"];
    buildFlags = [ "u-boot-with-nand-spl.imx" ];
    extraConfig = ''
      CONFIG_CMD_SETEXPR=y
    '';
    # sata init; load sata 0 $loadaddr u-boot-with-nand-spl.imx
    # sf probe; sf update $loadaddr 0 80000
  };

  ubootWandboard = buildUBoot {
    defconfig = "wandboard_defconfig";
    extraMeta.platforms = ["armv7l-linux"];
    filesToInstall = ["u-boot.img" "SPL"];
  };

  ubootRockPi4 = buildUBoot {
    defconfig = "rock-pi-4-rk3399_defconfig";
    extraMeta.platforms = ["aarch64-linux"];
    BL31 = "${armTrustedFirmwareRK3399}/bl31.elf";
    filesToInstall = [ "u-boot.itb" "idbloader.img"];
  };
}
