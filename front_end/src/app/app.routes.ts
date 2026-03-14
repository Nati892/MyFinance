import { Routes } from '@angular/router';
import { LoginComponent } from './components/login/login.component';
import { MainLayoutComponent } from './components/main-layout/main-layout.component';
import { HomeComponent } from './components/home/home.component';
import { LogsComponent } from './components/logs/logs.component';
import { AuthGuard } from './guards/auth.guard';
import { SettingsComponent } from './components/settings/settings.component';
import { AppUsersComponent } from './components/app-users/app-users.component';
import { HouseholdsComponent } from './components/households/households.component';

import { AppLoginComponent } from './pages/app-login/app-login.component';
import { AppLayoutComponent } from './layout/app-layout/app-layout.component';
import { AppAuthGuard } from './guards/app-auth.guard';
import { AppExpensesComponent } from './pages/app-expenses/app-expenses.component';
import { AppIncomesComponent } from './pages/app-incomes/app-incomes.component';

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
          { path: '', redirectTo: 'expenses', pathMatch: 'full' }
        ]
      },
      { path: '', redirectTo: 'login', pathMatch: 'full' }
    ]
  },
  { path: '**', redirectTo: 'login' }
];
