import { Dialog, DialogRef } from '@angular/cdk/dialog';
import { ComponentType } from '@angular/cdk/portal';
import { Injectable, inject } from '@angular/core';
import { firstValueFrom } from 'rxjs';

import { ConfirmDialog, ConfirmOptions } from './confirm-dialog';

export interface OverlayOptions<D> {
  data?: D;
  /** "drawer": a side panel on wide screens, a bottom sheet on phones. */
  variant?: 'dialog' | 'drawer';
  wide?: boolean;
}

/**
 * Opens dialogs and drawers (the app's bottom sheets) on the CDK Dialog:
 * focus trap, Escape to close, backdrop, scroll lock, focus restored.
 */
@Injectable({ providedIn: 'root' })
export class Overlay {
  private readonly dialog = inject(Dialog);

  open<R = unknown, D = unknown, C = unknown>(
    component: ComponentType<C>,
    options: OverlayOptions<D> = {},
  ): DialogRef<R, C> {
    const drawer = options.variant === 'drawer';
    return this.dialog.open<R, D, C>(component, {
      data: options.data,
      panelClass: drawer
        ? 'fm-drawer-panel'
        : ['fm-dialog-panel', ...(options.wide ? ['fm-wide'] : [])],
      backdropClass: 'cdk-overlay-dark-backdrop',
      autoFocus: 'first-tabbable',
      restoreFocus: true,
    });
  }

  /** The dialog's result, undefined if dismissed. */
  result<R = unknown, D = unknown, C = unknown>(
    component: ComponentType<C>,
    options: OverlayOptions<D> = {},
  ): Promise<R | undefined> {
    return firstValueFrom(this.open<R, D, C>(component, options).closed);
  }

  /** True if the user confirmed. */
  async confirm(options: ConfirmOptions): Promise<boolean> {
    return (await this.result<boolean, ConfirmOptions>(ConfirmDialog, { data: options })) === true;
  }
}
