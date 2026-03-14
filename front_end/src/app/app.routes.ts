import { Routes } from '@angular/router';
import { LoginComponent } from './components/login/login.component';
import { MainLayoutComponent } from './components/main-layout/main-layout.component';
import { HomeComponent } from './components/home/home.component';
import { LogsComponent } from './components/logs/logs.component';
import { AuthGuard } from './guards/auth.guard';
import { SettingsComponent } from './components/settings/settings.component';

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
    ]
  },
  { path: '**', redirectTo: 'login' }
];