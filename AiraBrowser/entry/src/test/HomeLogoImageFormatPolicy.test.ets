import { describe, expect, it } from '@ohos/hypium';
import {
  detectHomeLogoImageFormat,
  HOME_LOGO_FILE_PICKER_FILTER,
  isHomeLogoSvgText,
  isSupportedHomeLogoExtension,
  normalizeHomeLogoExtension,
  resolveHomeLogoAssetKind,
  resolveHomeLogoExtensionForFormat,
  resolveHomeLogoSvgSize
} from '../main/ets/core/settings/HomeLogoImageFormatPolicy';

function bytes(values: number[]): Uint8Array {
  return new Uint8Array(values);
}

export default function homeLogoImageFormatPolicyTest(): void {
  describe('HomeLogoImageFormatPolicy', () => {
    it('normalizes_and_folds_extension_aliases', 0, () => {
      expect(normalizeHomeLogoExtension('IMG.JPEG')).assertEqual('jpg');
      expect(normalizeHomeLogoExtension('image.heif')).assertEqual('heic');
      expect(normalizeHomeLogoExtension('marks.tif')).assertEqual('tiff');
      expect(normalizeHomeLogoExtension('dir/logo.svg?rev=1#x')).assertEqual('svg');
      expect(normalizeHomeLogoExtension('noextension')).assertEqual('');
      expect(normalizeHomeLogoExtension('trailing.')).assertEqual('');
    });

    it('accepts_mainstream_formats_and_svg', 0, () => {
      expect(isSupportedHomeLogoExtension('png')).assertTrue();
      expect(isSupportedHomeLogoExtension('jpg')).assertTrue();
      expect(isSupportedHomeLogoExtension('gif')).assertTrue();
      expect(isSupportedHomeLogoExtension('webp')).assertTrue();
      expect(isSupportedHomeLogoExtension('bmp')).assertTrue();
      expect(isSupportedHomeLogoExtension('heic')).assertTrue();
      expect(isSupportedHomeLogoExtension('avif')).assertTrue();
      expect(isSupportedHomeLogoExtension('tiff')).assertTrue();
      expect(isSupportedHomeLogoExtension('svg')).assertTrue();
      expect(isSupportedHomeLogoExtension('pdf')).assertFalse();
      expect(isSupportedHomeLogoExtension('txt')).assertFalse();
      expect(isSupportedHomeLogoExtension('')).assertFalse();
    });

    it('treats_only_svg_as_vector', 0, () => {
      expect(resolveHomeLogoAssetKind('svg')).assertEqual('vector');
      expect(resolveHomeLogoAssetKind('png')).assertEqual('raster');
      expect(resolveHomeLogoAssetKind('gif')).assertEqual('raster');
    });

    it('keeps_the_picker_filter_inside_the_suffix_limit', 0, () => {
      expect(HOME_LOGO_FILE_PICKER_FILTER.length <= 100).assertTrue();
      expect(HOME_LOGO_FILE_PICKER_FILTER.indexOf('.svg') >= 0).assertTrue();
      expect(HOME_LOGO_FILE_PICKER_FILTER.indexOf('.gif') >= 0).assertTrue();
    });

    it('detects_bitmap_signatures', 0, () => {
      expect(detectHomeLogoImageFormat(bytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])))
        .assertEqual('png');
      expect(detectHomeLogoImageFormat(bytes([0xFF, 0xD8, 0xFF, 0xE0]))).assertEqual('jpeg');
      expect(detectHomeLogoImageFormat(bytes([0x47, 0x49, 0x46, 0x38, 0x39, 0x61])))
        .assertEqual('gif');
      expect(detectHomeLogoImageFormat(bytes([0x42, 0x4D, 0x36, 0x00]))).assertEqual('bmp');
      expect(detectHomeLogoImageFormat(bytes([
        0x52, 0x49, 0x46, 0x46, 0x00, 0x00, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50
      ]))).assertEqual('webp');
      expect(detectHomeLogoImageFormat(bytes([0x00, 0x00, 0x01, 0x00, 0x01]))).assertEqual('ico');
      expect(detectHomeLogoImageFormat(bytes([0x49, 0x49, 0x2A, 0x00]))).assertEqual('tiff');
      expect(detectHomeLogoImageFormat(bytes([0x4D, 0x4D, 0x00, 0x2A]))).assertEqual('tiff');
      expect(detectHomeLogoImageFormat('not an image'.split('').map((c: string) => c.charCodeAt(0))))
        .assertEqual('');
    });

    it('tells_heic_and_avif_apart_by_brand', 0, () => {
      expect(detectHomeLogoImageFormat(bytes([
        0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69, 0x63
      ]))).assertEqual('heic');
      expect(detectHomeLogoImageFormat(bytes([
        0x00, 0x00, 0x00, 0x1C, 0x66, 0x74, 0x79, 0x70, 0x61, 0x76, 0x69, 0x66
      ]))).assertEqual('avif');
      expect(detectHomeLogoImageFormat(bytes([
        0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x6D, 0x70, 0x34, 0x32
      ]))).assertEqual('');
    });

    it('reads_a_svg_root_tag', 0, () => {
      expect(isHomeLogoSvgText('<svg xmlns="http://www.w3.org/2000/svg"></svg>')).assertTrue();
      expect(isHomeLogoSvgText('<?xml version="1.0"?>\n<svg viewBox="0 0 1 1"/>')).assertTrue();
      expect(isHomeLogoSvgText('{"not":"svg"}')).assertFalse();
    });

    it('measures_svg_from_attributes_then_viewbox', 0, () => {
      const withAttributes = resolveHomeLogoSvgSize('<svg width="337" height="337" viewBox="0 0 10 10"></svg>');
      expect(withAttributes.width).assertEqual(337);
      expect(withAttributes.height).assertEqual(337);

      const withUnits = resolveHomeLogoSvgSize('<svg width="120px" height="40px"/>');
      expect(withUnits.width).assertEqual(120);
      expect(withUnits.height).assertEqual(40);

      const fromViewBox = resolveHomeLogoSvgSize('<svg viewBox="0 0 546 163"/>');
      expect(fromViewBox.width).assertEqual(546);
      expect(fromViewBox.height).assertEqual(163);

      const commas = resolveHomeLogoSvgSize("<svg viewBox='0,0,320,120'/>");
      expect(commas.width).assertEqual(320);
      expect(commas.height).assertEqual(120);
    });

    it('ignores_percentages_and_stroke_width', 0, () => {
      const percent = resolveHomeLogoSvgSize('<svg width="100%" height="100%"/>');
      expect(percent.width).assertEqual(0);
      expect(percent.height).assertEqual(0);

      // stroke-width must not answer for width.
      const stroked = resolveHomeLogoSvgSize('<svg stroke-width="4" viewBox="0 0 200 50"></svg>');
      expect(stroked.width).assertEqual(200);
      expect(stroked.height).assertEqual(50);

      const empty = resolveHomeLogoSvgSize('plain text');
      expect(empty.width).assertEqual(0);
      expect(empty.height).assertEqual(0);
    });

    it('maps_a_detected_format_back_to_a_file_extension', 0, () => {
      expect(resolveHomeLogoExtensionForFormat('jpeg')).assertEqual('jpg');
      expect(resolveHomeLogoExtensionForFormat('png')).assertEqual('png');
      expect(resolveHomeLogoExtensionForFormat('heic')).assertEqual('heic');
      expect(resolveHomeLogoExtensionForFormat('')).assertEqual('');
    });
  });
}
