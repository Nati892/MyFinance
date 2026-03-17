import {
  Component,
  OnInit,
  OnDestroy,
  ChangeDetectionStrategy,
  ChangeDetectorRef,
} from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Subscription } from 'rxjs';

import { TranslateModule } from '@ngx-translate/core';

import { AssetsService, Asset } from '../../services/assets.service';
import { HouseholdStateService } from '../../services/household-state.service';

export interface AssetGroup {
  name: string;
  assets: Asset[];
  frontendTotal: number;
  backendTotal: number | null;
  mismatch: boolean;
}

@Component({
  selector: 'app-app-assets',
  standalone: true,
  imports: [CommonModule, FormsModule, TranslateModule],
  templateUrl: './app-assets.component.html',
  styleUrls: ['./app-assets.component.css'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class AppAssetsComponent implements OnInit, OnDestroy {
  // ── State ──────────────────────────────────────────────────────────────────
  assets: Asset[] = [];
  householdId: number | null = null;
  loading = false;
  noHousehold = false;
  editingCell: { assetId: number; field: keyof Asset } | null = null;
  pendingSave = new Map<number, Partial<Asset>>();
  backendGroupTotals: Record<string, number> = {};
  totalMismatchError = false;

  /** Skeleton placeholder rows shown during initial load */
  readonly skeletonRows = Array(5).fill(null);

  private subs = new Subscription();

  constructor(
    private assetsService: AssetsService,
    private householdState: HouseholdStateService,
    private cdr: ChangeDetectorRef,
  ) {}

  ngOnInit(): void {
    const household = this.householdState.getSelectedHousehold();
    if (!household) {
      this.noHousehold = true;
      return;
    }
    this.householdId = household.householdId;
    this.loadAssets();

    this.subs.add(
      this.householdState.selectedHousehold$.subscribe(h => {
        if (h && h.householdId !== this.householdId) {
          this.householdId = h.householdId;
          this.noHousehold = false;
          this.editingCell = null;
          this.pendingSave.clear();
          this.loadAssets();
          this.cdr.markForCheck();
        }
      })
    );
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  loadAssets(): void {
    if (this.householdId == null) return;
    this.loading = true;
    this.assetsService.list(this.householdId).subscribe({
      next: res => {
        this.assets = res.assets ?? [];
        this.backendGroupTotals = res.groupTotals ?? {};
        this.loading = false;
        this.cdr.markForCheck();
      },
      error: () => {
        this.loading = false;
        this.cdr.markForCheck();
      },
    });
  }

  // ── Asset groups ───────────────────────────────────────────────────────────

  get assetGroups(): AssetGroup[] {
    const map = new Map<string, Asset[]>();
    for (const a of this.assets) {
      const key = (a.name || '').trim();
      if (!map.has(key)) map.set(key, []);
      map.get(key)!.push(a);
    }
    return Array.from(map.entries()).map(([name, assets]) => {
      const sorted = [...assets].sort((a, b) => {
        if (!a.date && !b.date) return 0;
        if (!a.date) return 1;
        if (!b.date) return -1;
        return new Date(a.date).getTime() - new Date(b.date).getTime();
      });
      const frontendTotal = parseFloat(sorted.reduce((sum, a) => sum + (parseFloat(String(a.value)) || 0), 0).toFixed(2));
      const backendTotal = this.backendGroupTotals[name] ?? null;
      const mismatch = backendTotal !== null && Math.abs(backendTotal - frontendTotal) > 0.01;
      return { name, assets: sorted, frontendTotal, backendTotal, mismatch };
    });
  }

  trackByName(_: number, group: AssetGroup): string {
    return group.name;
  }

  // ── Inline editing ─────────────────────────────────────────────────────────

  startEdit(assetId: number, field: keyof Asset): void {
    this.editingCell = { assetId, field };
    this.cdr.markForCheck();
  }

  isEditing(assetId: number, field: keyof Asset): boolean {
    return (
      this.editingCell?.assetId === assetId &&
      this.editingCell?.field === field
    );
  }

  onCellChange(asset: Asset, field: keyof Asset, value: any): void {
    const pending = this.pendingSave.get(asset.id) ?? {};
    pending[field] = value;
    this.pendingSave.set(asset.id, pending);

    // Also update local model immediately for responsive UI
    (asset as any)[field] = value;
    this.cdr.markForCheck();
  }

  onCellBlur(asset: Asset, field: keyof Asset): void {
    if (
      this.editingCell?.assetId === asset.id &&
      this.editingCell?.field === field
    ) {
      this.saveAsset(asset);
      this.editingCell = null;
      this.cdr.markForCheck();
    }
  }

  onCellKeydown(event: KeyboardEvent, asset: Asset, field: keyof Asset): void {
    if (event.key === 'Enter') {
      (event.target as HTMLElement).blur();
    }
    if (event.key === 'Escape') {
      this.editingCell = null;
      this.pendingSave.delete(asset.id);
      this.loadAssets();
      this.cdr.markForCheck();
    }
  }

  cancelEdit(): void {
    this.editingCell = null;
    this.cdr.markForCheck();
  }

  onLiquidityChange(asset: Asset, value: 'high' | 'medium' | 'low'): void {
    asset.liquidity = value;
    this.editingCell = null;
    this.saveAsset(asset);
    this.cdr.markForCheck();
  }

  private saveAsset(asset: Asset): void {
    const changes = this.pendingSave.get(asset.id);
    if (!changes || Object.keys(changes).length === 0) return;

    this.pendingSave.delete(asset.id);
    this.assetsService.update(asset.id, changes).subscribe({
      next: res => {
        const idx = this.assets.findIndex(a => a.id === asset.id);
        if (idx !== -1) {
          this.assets[idx] = res.asset ?? { ...asset, ...changes };
        }
        this.cdr.markForCheck();
      },
      error: () => {
        // Reload to revert on failure
        this.loadAssets();
      },
    });
  }

  // ── Add / Delete ───────────────────────────────────────────────────────────

  addAsset(): void {
    if (this.householdId == null) return;
    const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
    const maxOrder = this.assets.reduce((m, a) => Math.max(m, a.sortOrder ?? 0), 0);
    this.assetsService.create({
      name: 'New Asset',
      value: 0,
      liquidity: 'medium',
      description: '',
      householdId: this.householdId,
      sortOrder: maxOrder + 1,
      date: today,
    }).subscribe({
      next: res => {
        this.assets = [...this.assets, res.asset];
        this.editingCell = { assetId: res.asset.id, field: 'name' };
        this.cdr.markForCheck();
      },
      error: () => alert('Failed to create asset.'),
    });
  }

  deleteAsset(asset: Asset): void {
    if (!confirm(`Delete "${asset.name}"?`)) return;
    this.assetsService.delete(asset.id).subscribe({
      next: () => {
        this.assets = this.assets.filter(a => a.id !== asset.id);
        this.cdr.markForCheck();
      },
      error: () => alert('Failed to delete asset. Please try again.'),
    });
  }

  // ── Summary computations ───────────────────────────────────────────────────

  get totalValue(): number {
    return this.assets.reduce((sum, a) => sum + (a.value ?? 0), 0);
  }

  get liquidValue(): number {
    return this.assets
      .filter(a => a.liquidity === 'high')
      .reduce((sum, a) => sum + (a.value ?? 0), 0);
  }

  get semiLiquidValue(): number {
    return this.assets
      .filter(a => a.liquidity === 'medium')
      .reduce((sum, a) => sum + (a.value ?? 0), 0);
  }

  get illiquidValue(): number {
    return this.assets
      .filter(a => a.liquidity === 'low')
      .reduce((sum, a) => sum + (a.value ?? 0), 0);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  formatCurrency(value: number): string {
    return '₪' + value.toLocaleString('en-IL', { minimumFractionDigits: 0, maximumFractionDigits: 0 });
  }

  liquidityLabel(l: 'high' | 'medium' | 'low'): string {
    return l === 'high' ? 'High' : l === 'medium' ? 'Medium' : 'Low';
  }

  liquidityDot(l: 'high' | 'medium' | 'low'): string {
    return l === 'high' ? '🟢' : l === 'medium' ? '🟡' : '🔴';
  }

  trackById(_: number, item: Asset): number {
    return item.id;
  }
}
