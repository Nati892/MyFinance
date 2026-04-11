import { Routes } from '@angular/router';
import { LoginComponent } from './components/login/login.component';
import { MainLayoutComponent } from './components/main-layout/main-layout.component';
import { HomeComponent } from './components/home/home.component';
import { LogsComponent } from './components/logs/logs.component';
import { AuthGuard } from './guards/auth.guard';
import { SettingsComponent } from './components/settings/settings.component';
import { AppUsersComponent } from './components/app-users/app-users.component';
import { HouseholdsComponent } from './components/households/households.component';
import { ApkManagementComponent } from './components/apk-management/apk-management.component';

import { AppLoginComponent } from './pages/app-login/app-login.component';
import { AppLayoutComponent } from './layout/app-layout/app-layout.component';
import { AppAuthGuard } from './guards/app-auth.guard';
import { AppExpensesComponent } from './pages/app-expenses/app-expenses.component';
import { AppIncomesComponent } from './pages/app-incomes/app-incomes.component';
import { AppHomeComponent } from './pages/app-home/app-home.component';
import { AppBudgetComponent } from './pages/app-budget/app-budget.component';
import { AppAssetsComponent } from './pages/app-assets/app-assets.component';
import { AppTransactionsComponent } from './pages/app-transactions/app-transactions.component';

export const routes: Routes = [
  { path: 'login', component: LoginComponent },
  {
    path: '',
    component: MainLayoutComponent,
    canActivate: [AuthGuard],
    children: [
      { path: '', redirectTo: 'home', pathMatch: 'full' },
      { path: 'home', component: HomeComponent },
      { path: 'logs', component: LogsComponent },
      { path: 'settings', component: SettingsComponent },
      { path: 'app-users', component: AppUsersComponent },
      { path: 'households', component: HouseholdsComponent },
      { path: 'app-management', component: ApkManagementComponent },
    ]
  },
  {
    path: 'app',
    children: [
      { path: 'login', component: AppLoginComponent },
      {
        path: '',
        component: AppLayoutComponent,
        canActivate: [AppAuthGuard],
        children: [
          { path: 'expenses', component: AppExpensesComponent },
          { path: 'incomes', component: AppIncomesComponent },
          { path: 'transactions', component: AppTransactionsComponent },
          { path: 'home', component: AppHomeComponent },
          { path: 'budget', component: AppBudgetComponent },
          { path: 'assets', component: AppAssetsComponent },
          { path: '', redirectTo: 'transactions', pathMatch: 'full' }
        ]
      },
      { path: '', redirectTo: 'login', pathMatch: 'full' }
    ]
  },
  { path: '**', redirectTo: 'login' }
];
