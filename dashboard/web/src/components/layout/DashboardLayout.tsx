'use client';

import { useState } from 'react';
import { ReactNode } from 'react';
import { cn } from '@/lib/utils';
import { Sidebar } from '@/components/layout/Sidebar';
import { Header } from '@/components/layout/Header';

interface DashboardLayoutProps {
  children: ReactNode;
}

export function DashboardLayout({ children }: DashboardLayoutProps) {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false);

  const toggleSidebar = () => setSidebarOpen(!sidebarOpen);
  const closeSidebar = () => setSidebarOpen(false);
  const toggleSidebarCollapse = () => setSidebarCollapsed(!sidebarCollapsed);

  return (
    <div className="min-h-screen bg-bg">
      <Sidebar
        isOpen={sidebarOpen}
        onClose={closeSidebar}
        onToggleCollapse={toggleSidebarCollapse}
        isCollapsed={sidebarCollapsed}
      />
      
      <div className={cn('lg:pl-64 transition-all duration-300', sidebarCollapsed ? 'lg:pl-16' : '')}>
        <Header onMenuClick={toggleSidebar} />
        
        <main className={cn('pt-16 min-h-screen', sidebarCollapsed ? 'lg:pl-4' : 'lg:pl-6')}>
          <div className="p-4 lg:p-6 max-w-full">
            {children}
          </div>
        </main>
      </div>
    </div>
  );
}