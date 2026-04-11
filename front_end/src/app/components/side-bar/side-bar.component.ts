import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink, RouterLinkActive } from '@angular/router';

@Component({
  selector: 'app-side-bar',
  standalone: true,
  imports: [CommonModule, RouterLink, RouterLinkActive],
  templateUrl: './side-bar.component.html',
  styleUrls: ['./side-bar.component.css']
})
export class SideBarComponent {
  isCollapsed = false;
  
  menuItems = [
    { 
      path: '/home', 
      label: 'Home', 
      icon: 'fa-solid fa-house'
    },
    { 
      path: '/logs', 
      label: 'Logs', 
      icon: 'fa-solid fa-clipboard-list'
    },
    {
      path: '/settings',
      label: 'Settings',
      icon: 'fa-solid fa-gear'
    },
    {
      path: '/app-users',
      label: 'App Users',
      icon: 'fa-solid fa-users'
    },
    {
      path: '/households',
      label: 'Households',
      icon: 'fa-solid fa-house-chimney'
    },
    {
      path: '/app-management',
      label: 'App Management',
      icon: 'fa-solid fa-mobile-screen-button'
    }
  ];

  toggleSidebar(): void {
    this.isCollapsed = !this.isCollapsed;
  }
}