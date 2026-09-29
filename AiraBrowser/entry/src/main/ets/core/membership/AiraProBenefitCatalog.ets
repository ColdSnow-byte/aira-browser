/**
 * The Aira Pro benefit list, shared by the membership page and the renewal
 * sheet. Both surfaces make the same promise to the user, so they must not
 * carry independent copies of it: a benefit added to one is then advertised by
 * the other automatically.
 *
 * Titles are kept short because the renewal sheet renders them as compact
 * rows. There is deliberately no description and no per-row action: the
 * membership page lists the capabilities as single-line rows, so a caption or a
 * “查看教程” link inside the list was content the page never rendered. The
 * desktop setup guide still has its own entry points on the sync and
 * cross-device-link surfaces, which is where a user going to set up a desktop
 * extension actually is.
 */
import { AiraRenderableIconId } from '../resources/GeneratedAiraIconCatalog';

export interface AiraProBenefitDefinition {
  id: string;
  title: string;
  iconId: AiraRenderableIconId;
}

export const AIRA_PRO_BENEFITS: AiraProBenefitDefinition[] = [
  {
    id: 'cross_system_bookmark_sync',
    title: 'Aira 云书签同步',
    iconId: 'membership.benefit.sync'
  },
  {
    id: 'page_handoff',
    title: 'Aira 云网页接力',
    iconId: 'browser.toolbar.sendToDesktop'
  },
  {
    id: 'cross_device_tabs',
    title: 'Aira 云跨设备标签页',
    iconId: 'browser.toolbar.tabs'
  },
  {
    id: 'aira_cloud_history',
    title: 'Aira 云历史同步',
    iconId: 'membership.benefit.sync'
  }
];

/**
 * The desktop endpoints Aira Pro reaches. The row plays the same role as the
 * model logos on a subscription page: it answers which browsers this covers
 * without repeating the benefit list above it.
 *
 * The desktop entry is the browser, not the operating system, because
 * Aira-sync installs into Chrome, Edge, and Firefox on either Windows or macOS.
 * The HarmonyOS client itself is not listed; this page is already that app.
 */
export type AiraProReachableDeviceGlyph = 'chrome' | 'edge' | 'firefox';

export interface AiraProReachableDeviceDefinition {
  id: string;
  label: string;
  glyph: AiraProReachableDeviceGlyph;
}

export const AIRA_PRO_REACHABLE_DEVICES: AiraProReachableDeviceDefinition[] = [
  // Browser extensions, not desktop apps: Aira itself only ships for
  // HarmonyOS, and the desktop side is Aira-sync.
  { id: 'chrome', label: 'Chrome 扩展', glyph: 'chrome' },
  { id: 'edge', label: 'Edge 扩展', glyph: 'edge' },
  { id: 'firefox', label: 'Firefox 扩展', glyph: 'firefox' }
];
