import {
  BrowserSearchInvocationEndReason,
  BrowserSearchInvocationSurfaceAdapter,
  BrowserSearchPresentationCommitResult,
  BrowserSearchPresentationRequest,
  BrowserSearchSceneSnapshot
} from './BrowserSearchInvocationSessionCoordinator';
import { BrowserSearchInvocationHostKind } from './BrowserSearchInvocationHostPolicy';

export interface BrowserSearchInvocationHostRouterHost {
  resolveHostKind: () => BrowserSearchInvocationHostKind;
}

/**
 * One registered surface. Host choice happens at present time, so a toolbar
 * change does not depend on the shell reconnecting before the next open.
 * Switching hosts suspends the previous child and presents the new one with
 * the same session authority.
 */
export class BrowserSearchInvocationHostRouter implements BrowserSearchInvocationSurfaceAdapter {
  private readonly host: BrowserSearchInvocationHostRouterHost;
  private readonly floatingAdapter: BrowserSearchInvocationSurfaceAdapter;
  private readonly splitAdapter: BrowserSearchInvocationSurfaceAdapter;
  private readonly largeScreenAdapter: BrowserSearchInvocationSurfaceAdapter;
  private activeKind: BrowserSearchInvocationHostKind = 'unavailable';
  private activeAdapter: BrowserSearchInvocationSurfaceAdapter | undefined = undefined;

  constructor(
    host: BrowserSearchInvocationHostRouterHost,
    floatingAdapter: BrowserSearchInvocationSurfaceAdapter,
    splitAdapter: BrowserSearchInvocationSurfaceAdapter,
    largeScreenAdapter: BrowserSearchInvocationSurfaceAdapter
  ) {
    this.host = host;
    this.floatingAdapter = floatingAdapter;
    this.splitAdapter = splitAdapter;
    this.largeScreenAdapter = largeScreenAdapter;
  }

  resolveScene(): BrowserSearchSceneSnapshot {
    return this.adapterFor(this.host.resolveHostKind()).resolveScene();
  }

  async present(request: BrowserSearchPresentationRequest): Promise<BrowserSearchPresentationCommitResult> {
    const kind = this.host.resolveHostKind();
    if (kind === 'unavailable') {
      this.retarget(kind, request.authorityId);
      return new BrowserSearchPresentationCommitResult('failed', 'presentation_commit_failed');
    }
    this.retarget(kind, request.authorityId);
    const adapter = this.activeAdapter;
    if (adapter === undefined) {
      return new BrowserSearchPresentationCommitResult('failed', 'presentation_commit_failed');
    }
    return adapter.present(request);
  }

  suspend(authorityId: string): void {
    this.activeAdapter?.suspend(authorityId);
  }

  end(authorityId: string, reason: BrowserSearchInvocationEndReason): void {
    this.activeAdapter?.end(authorityId, reason);
  }

  private retarget(kind: BrowserSearchInvocationHostKind, authorityId: string): void {
    const next = kind === 'unavailable' ? undefined : this.adapterFor(kind);
    if (this.activeKind === kind && this.activeAdapter === next) {
      return;
    }
    const previous = this.activeAdapter;
    this.activeKind = kind;
    this.activeAdapter = next;
    if (previous !== undefined && previous !== next) {
      previous.suspend(authorityId);
    }
  }

  private adapterFor(kind: BrowserSearchInvocationHostKind): BrowserSearchInvocationSurfaceAdapter {
    if (kind === 'large_screen') {
      return this.largeScreenAdapter;
    }
    if (kind === 'split') {
      return this.splitAdapter;
    }
    return this.floatingAdapter;
  }
}
