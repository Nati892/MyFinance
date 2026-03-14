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
    }
  ];

  toggleSidebar(): void {
    this.isCollapsed = !this.isCollapsed;
  }
}