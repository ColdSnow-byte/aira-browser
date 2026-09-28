import { describe, expect, it } from '@ohos/hypium';
import {
  buildHomeLogoCustomAssetId,
  findHomeLogoCustomAsset,
  HOME_LOGO_BUILTIN_ID,
  HomeLogoCustomAsset,
  HomeLogoSelection,
  normalizeHomeLogoSelection,
  resolveHomeLogoDisplaySource,
  resolveHomeLogoRowLabel
} from '../main/ets/common/models/HomeLogoModels';
import {
  buildHomeLogoGridRows,
  buildHomeLogoSettingsViewState,
  formatHomeLogoScaleLabel,
  HOME_LOGO_ADD_ITEM_ID,
  HOME_LOGO_SCALE_DEFAULT_RATIO,
  HOME_LOGO_SCALE_MAX_RATIO,
  HOME_LOGO_SCALE_MIN_RATIO,
  homeLogoScaleToSliderValue,
  homeLogoSliderValueToScale,
  normalizeHomeLogoScaleRatio,
  resolveHomeLogoDisplayWidthVp,
  resolveHomeLogoGridColumns,
  resolveHomeLogoHeightVp
} from '../main/ets/core/settings/HomeLogoSettingsPolicy';

function selectionWith(id: string, customUris: string[]): HomeLogoSelection {
  const customAssets: HomeLogoCustomAsset[] = [];
  for (let index = 0; index < customUris.length; index += 1) {
    const uri = customUris[index];
    customAssets.push({
      id: buildHomeLogoCustomAssetId(1000 + index),
      uri: uri,
      fileName: uri.substring(uri.lastIndexOf('/') + 1),
      width: 400,
      height: 120
    });
  }
  return { id: id, customAssets: customAssets };
}

export default function homeLogoSettingsPolicyTest(): void {
  describe('HomeLogoSettingsPolicy', () => {
    it('uses_two_columns_on_a_phone_and_more_when_wider', 0, () => {
      expect(resolveHomeLogoGridColumns(328)).assertEqual(2);
      expect(resolveHomeLogoGridColumns(439)).assertEqual(2);
      expect(resolveHomeLogoGridColumns(440)).assertEqual(3);
      expect(resolveHomeLogoGridColumns(679)).assertEqual(3);
      expect(resolveHomeLogoGridColumns(680)).assertEqual(4);
    });

    it('keeps_height_fixed_and_lets_width_follow_the_image', 0, () => {
      expect(Math.round(resolveHomeLogoDisplayWidthVp(546, 163, 53, 0))).assertEqual(177);
      expect(Math.round(resolveHomeLogoDisplayWidthVp(100, 200, 53, 0))).assertEqual(27);
      expect(resolveHomeLogoDisplayWidthVp(2000, 100, 53, 200)).assertEqual(200);
      expect(resolveHomeLogoDisplayWidthVp(0, 0, 53, 0)).assertEqual(53);
    });

    it('ends_the_grid_with_the_add_tile_and_no_custom_images', 0, () => {
      const state = buildHomeLogoSettingsViewState(selectionWith(HOME_LOGO_BUILTIN_ID, []), 328);
      expect(state.items.length).assertEqual(5);
      expect(state.items[0].kind).assertEqual('preset');
      expect(state.items[0].title).assertEqual('默认');
      expect(state.items[1].title).assertEqual('父亲节');
      expect(state.items[2].title).assertEqual('世界杯');
      expect(state.items[3].title).assertEqual('德甲');
      expect(state.items[0].selected).assertTrue();
      expect(state.items[4].kind).assertEqual('add');
      expect(state.items[4].id).assertEqual(HOME_LOGO_ADD_ITEM_ID);
      expect(state.items[4].selected).assertFalse();
      // The add tile must not be selectable, so it never takes the accent border.
      expect(state.items[4].fileUri).assertEqual('');
      expect(state.items[4].rawfileName).assertEqual('');
    });

    it('appends_each_custom_image_before_the_add_tile', 0, () => {
      const first = selectionWith('builtin', ['file://a.png']);
      const withOne = buildHomeLogoSettingsViewState(first, 328);
      expect(withOne.items.length).assertEqual(6);
      expect(withOne.items[4].kind).assertEqual('custom');
      expect(withOne.items[4].fileUri).assertEqual('file://a.png');
      // The tile is labelled with the file the user picked.
      expect(withOne.items[4].title).assertEqual('a.png');
      expect(withOne.items[5].kind).assertEqual('add');

      const customId = first.customAssets[0].id;
      const second = selectionWith(customId, ['file://a.png', 'file://b.png']);
      const withTwo = buildHomeLogoSettingsViewState(second, 328);
      expect(withTwo.items.length).assertEqual(7);
      expect(withTwo.items[4].kind).assertEqual('custom');
      expect(withTwo.items[5].kind).assertEqual('custom');
      expect(withTwo.items[5].fileUri).assertEqual('file://b.png');
      expect(withTwo.items[6].kind).assertEqual('add');
      expect(withTwo.items[4].selected).assertTrue();
    });

    it('fills_the_last_grid_row_so_tiles_stay_equal', 0, () => {
      const state = buildHomeLogoSettingsViewState(selectionWith('preset-1', []), 500);
      expect(state.columns).assertEqual(3);
      expect(state.items[1].selected).assertTrue();
      const rows = buildHomeLogoGridRows(state.items, state.columns);
      expect(rows.length).assertEqual(2);
      expect(rows[0].items.length).assertEqual(3);
      expect(rows[1].items.length).assertEqual(2);
      expect(rows[1].placeholderCount).assertEqual(1);
    });

    // ForEach reuses a node whose key is unchanged, so the row key must move with the selection
    // or the blue selection border stays on the previously chosen tile.
    it('moves_the_row_key_when_the_selection_changes', 0, () => {
      const first = buildHomeLogoSettingsViewState(selectionWith('preset-1', []), 500);
      const second = buildHomeLogoSettingsViewState(selectionWith('preset-2', []), 500);
      const firstRowKey = buildHomeLogoGridRows(first.items, first.columns)[0].key;
      const secondRowKey = buildHomeLogoGridRows(second.items, second.columns)[0].key;
      expect(firstRowKey !== secondRowKey).assertTrue();

      // The same selection must keep a stable key so nothing rebuilds needlessly.
      const repeatRowKey = buildHomeLogoGridRows(first.items, first.columns)[0].key;
      expect(firstRowKey).assertEqual(repeatRowKey);
    });

    it('drops_a_custom_entry_that_has_no_file', 0, () => {
      const selection = normalizeHomeLogoSelection({
        id: 'custom-1000',
        customAssets: [
          { id: 'custom-1000', uri: '   ', fileName: 'x.png', width: 80, height: 40 },
          { id: '', uri: 'file://b.png', fileName: 'b.png', width: 10, height: 10 }
        ]
      });
      expect(selection.customAssets.length).assertEqual(0);
      // Nothing left to select, so the choice falls back to the shipped wordmark.
      expect(selection.id).assertEqual(HOME_LOGO_BUILTIN_ID);
      expect(resolveHomeLogoDisplaySource(selection).rawfileName).assertEqual('home_centered_wordmark.svg');
      expect(resolveHomeLogoRowLabel(selection)).assertEqual('默认');
    });

    it('falls_back_to_the_uri_name_when_no_name_was_stored', 0, () => {
      const selection = normalizeHomeLogoSelection({
        id: 'custom-1000',
        customAssets: [
          { id: 'custom-1000', uri: 'file://media/Photo/9/IMG_2024/IMG_20240101.jpg', fileName: '', width: 10, height: 10 }
        ]
      });
      expect(selection.customAssets[0].fileName).assertEqual('IMG_20240101.jpg');
    });

    it('selects_a_custom_image_and_labels_it', 0, () => {
      const selection = selectionWith('custom-1000', ['file://a.png', 'file://b.png']);
      expect(findHomeLogoCustomAsset(selection.customAssets, 'custom-1000')?.uri).assertEqual('file://a.png');
      const source = resolveHomeLogoDisplaySource(selection);
      expect(source.fileUri).assertEqual('file://a.png');
      expect(source.tintable).assertFalse();
      expect(resolveHomeLogoRowLabel(selection)).assertEqual('自定义');
    });
    it('clamps_the_size_slider_to_its_range', 0, () => {
      expect(HOME_LOGO_SCALE_DEFAULT_RATIO).assertEqual(1);
      expect(normalizeHomeLogoScaleRatio(1.25)).assertEqual(1.25);
      // Below the floor and above the cap both snap back inside the range.
      expect(normalizeHomeLogoScaleRatio(0.1)).assertEqual(HOME_LOGO_SCALE_MIN_RATIO);
      expect(normalizeHomeLogoScaleRatio(9)).assertEqual(HOME_LOGO_SCALE_MAX_RATIO);
      expect(normalizeHomeLogoScaleRatio(undefined)).assertEqual(HOME_LOGO_SCALE_DEFAULT_RATIO);
      expect(normalizeHomeLogoScaleRatio(Number.NaN)).assertEqual(HOME_LOGO_SCALE_DEFAULT_RATIO);
    });

    it('round_trips_between_ratio_and_slider_percent', 0, () => {
      expect(homeLogoScaleToSliderValue(1)).assertEqual(100);
      expect(homeLogoScaleToSliderValue(1.4)).assertEqual(140);
      expect(homeLogoSliderValueToScale(150)).assertEqual(1.5);
      expect(homeLogoSliderValueToScale(500)).assertEqual(HOME_LOGO_SCALE_MAX_RATIO);
      expect(formatHomeLogoScaleLabel(1.2)).assertEqual('120%');
    });

    it('scales_the_wordmark_height_and_never_passes_the_cap', 0, () => {
      // The shipped wordmark is 53vp, so 100% is exactly the current size.
      expect(resolveHomeLogoHeightVp(53, 1)).assertEqual(53);
      expect(resolveHomeLogoHeightVp(53, 2)).assertEqual(106);
      expect(resolveHomeLogoHeightVp(53, 0.6)).assertEqual(Math.round(53 * 0.6));
      // A ratio past the cap is clamped instead of growing without limit.
      expect(resolveHomeLogoHeightVp(53, 8)).assertEqual(106);
      expect(resolveHomeLogoHeightVp(53, 0)).assertEqual(HOME_LOGO_SCALE_DEFAULT_RATIO * 53);
    });
  });
}
