import { DIALOG_DATA, DialogRef } from '@angular/cdk/dialog';
import {
  ChangeDetectionStrategy,
  Component,
  computed,
  inject,
  resource,
  signal,
  viewChild,
} from '@angular/core';
import { TranslocoPipe, TranslocoService } from '@jsverse/transloco';
import { ImageCropperComponent } from 'ngx-image-cropper';
import { ImageUp, Pencil, RotateCcw, RotateCw, Search, Trash2 } from 'lucide';

import { ErrorText } from '../../core/errors/error-text';
import { Icon } from '../../shared/ui/icon';
import { MediaSrc } from '../../shared/ui/media-src';
import { Overlay } from '../../shared/ui/overlay';
import { Sheet, SheetFooter } from '../../shared/ui/sheet';
import { EmptyState, InlineError, Spinner } from '../../shared/ui/states';
import { Toasts } from '../../shared/ui/toast';
import { MediaApi, MediaAsset, MediaKind, MediaSearchResult } from './media.api';
import { RenameMediaDialog } from './rename-media-dialog';

type Tab = 'recent' | 'library' | 'search' | 'upload';

/**
 * Image picker (plan.md section 7.7): recent images, the library (search,
 * rename, delete), the external image search, and upload with a 1:1 crop
 * and rotation (section 7.8; round mask for profile pictures). Resolves with
 * the chosen or created asset.
 */
@Component({
  selector: 'app-media-picker-dialog',
  imports: [
    EmptyState,
    Icon,
    ImageCropperComponent,
    InlineError,
    MediaSrc,
    Sheet,
    SheetFooter,
    Spinner,
    TranslocoPipe,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './media-picker-dialog.html',
})
export class MediaPickerDialog {
  protected readonly ref = inject<DialogRef<MediaAsset>>(DialogRef);
  protected readonly kind = inject<MediaKind>(DIALOG_DATA);
  private readonly api = inject(MediaApi);
  private readonly overlay = inject(Overlay);
  private readonly toasts = inject(Toasts);
  private readonly transloco = inject(TranslocoService);
  protected readonly errorText = inject(ErrorText);

  protected readonly icons = { ImageUp, Pencil, RotateCcw, RotateCw, Search, Trash2 };
  protected readonly tabs: { id: Tab; key: string }[] = [
    { id: 'recent', key: 'mediaPickerRecentTab' },
    { id: 'library', key: 'mediaPickerLibraryTab' },
    { id: 'search', key: 'mediaPickerSearchTab' },
    { id: 'upload', key: 'mediaPickerUploadTab' },
  ];
  protected readonly tab = signal<Tab>('recent');

  // Recent and library: the user's stored images.
  protected readonly libraryQuery = signal('');
  private readonly libraryRevision = signal(0);
  protected readonly assets = resource({
    params: () => ({
      tab: this.tab(),
      q: this.tab() === 'library' ? this.libraryQuery() : '',
      revision: this.libraryRevision(),
    }),
    loader: ({ params }) =>
      params.tab === 'recent' || params.tab === 'library'
        ? this.api.list(this.kind, params.tab === 'recent', params.q)
        : Promise.resolve([] as MediaAsset[]),
  });

  // External search.
  protected readonly searchQuery = signal('');
  protected readonly results = resource({
    params: () =>
      this.searchQuery().trim().length >= 2 ? { q: this.searchQuery().trim() } : undefined,
    loader: ({ params }) => this.api.search(params.q),
  });
  protected readonly selecting = signal<string | null>(null);

  // Upload.
  protected readonly file = signal<File | null>(null);
  protected readonly rotation = signal(0);
  protected readonly uploading = signal(false);
  protected readonly dragging = signal(false);
  private readonly cropper = viewChild(ImageCropperComponent);
  protected readonly round = computed(() => this.kind === 'profile');

  private libraryTimer: ReturnType<typeof setTimeout> | undefined;
  private searchTimer: ReturnType<typeof setTimeout> | undefined;

  protected onLibraryInput(value: string): void {
    clearTimeout(this.libraryTimer);
    this.libraryTimer = setTimeout(() => this.libraryQuery.set(value), 400);
  }

  protected onSearchInput(value: string): void {
    clearTimeout(this.searchTimer);
    this.searchTimer = setTimeout(() => this.searchQuery.set(value), 400);
  }

  protected pick(asset: MediaAsset): void {
    this.ref.close(asset);
  }

  protected async rename(asset: MediaAsset, event: Event): Promise<void> {
    event.stopPropagation();
    const name = await this.overlay.result<string, string>(RenameMediaDialog, {
      data: asset.name ?? '',
    });
    if (!name) return;
    try {
      await this.api.rename(asset.id, name);
      this.libraryRevision.update((value) => value + 1);
    } catch {
      this.toasts.error(this.transloco.translate('mediaRenameFailedMessage'));
    }
  }

  protected async remove(asset: MediaAsset, event: Event): Promise<void> {
    event.stopPropagation();
    const confirmed = await this.overlay.confirm({
      title: this.transloco.translate('webDeleteImageTitle'),
      confirmLabel: this.transloco.translate('commonDelete'),
      destructive: true,
    });
    if (!confirmed) return;
    try {
      await this.api.delete(asset.id);
      this.libraryRevision.update((value) => value + 1);
    } catch (error) {
      this.toasts.error(this.errorText.message(error));
    }
  }

  protected async selectResult(result: MediaSearchResult): Promise<void> {
    this.selecting.set(result.external_id);
    try {
      this.ref.close(await this.api.selectFromSearch(this.kind, result.external_id));
    } catch {
      this.toasts.error(this.transloco.translate('mediaSelectFailedMessage'));
    } finally {
      this.selecting.set(null);
    }
  }

  protected onFile(files: FileList | null | undefined): void {
    const file = files?.[0];
    if (!file || !file.type.startsWith('image/')) return;
    this.rotation.set(0);
    this.file.set(file);
  }

  protected onDrop(event: DragEvent): void {
    event.preventDefault();
    this.dragging.set(false);
    this.onFile(event.dataTransfer?.files);
  }

  protected rotate(step: number): void {
    this.rotation.update((value) => (value + step + 4) % 4);
  }

  protected async upload(): Promise<void> {
    const cropped = await this.cropper()?.crop('blob');
    if (!cropped?.blob) return;
    this.uploading.set(true);
    try {
      this.ref.close(await this.api.upload(this.kind, cropped.blob, 'image.jpg'));
    } catch (error) {
      this.toasts.error(
        this.errorText.message(error) || this.transloco.translate('mediaUploadFailedMessage'),
      );
    } finally {
      this.uploading.set(false);
    }
  }
}
