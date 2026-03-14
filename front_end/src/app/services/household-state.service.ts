import { Injectable } from '@angular/core';
import { BehaviorSubject } from 'rxjs';
import { AppAuthService } from './app-auth.service';

export interface SelectedHousehold {
  householdId: number;
  householdName: string;
}

@Injectable({ providedIn: 'root' })
export class HouseholdStateService {
  private selectedHouseholdSubject = new BehaviorSubject<SelectedHousehold | null>(null);
  selectedHousehold$ = this.selectedHouseholdSubject.asObservable();

  constructor(private appAuthService: AppAuthService) {}

  setHousehold(household: SelectedHousehold): void {
    localStorage.setItem('selected_household', JSON.stringify(household));
    this.selectedHouseholdSubject.next(household);
  }

  getSelectedHousehold(): SelectedHousehold | null {
    if (this.selectedHouseholdSubject.value) {
      return this.selectedHouseholdSubject.value;
    }
    const stored = localStorage.getItem('selected_household');
    if (stored) {
      try {
        return JSON.parse(stored) as SelectedHousehold;
      } catch {
        return null;
      }
    }
    return null;
  }

  initFromStorage(): void {
    const stored = localStorage.getItem('selected_household');
    if (stored) {
      try {
        const household = JSON.parse(stored) as SelectedHousehold;
        this.selectedHouseholdSubject.next(household);
        return;
      } catch {
        // fall through to pick from user households
      }
    }

    const user = this.appAuthService.getCurrentUser();
    if (user && user.households && user.households.length > 0) {
      const first: SelectedHousehold = {
        householdId: user.households[0].householdId,
        householdName: user.households[0].householdName
      };
      this.setHousehold(first);
    }
  }
}
