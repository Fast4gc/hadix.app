'use client';

import { useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { motion, AnimatePresence } from 'framer-motion';
import { cn } from '@/lib/utils';
import {
  LayoutDashboard,
  FolderKanban,
  Rocket,
  Database,
  FileText,
  Terminal,
  Globe,
  HardDrive,
  Server,
  Settings,
  Users,
  BarChart3,
  Store,
  Shield,
  Bell,
  ChevronLeft,
  ChevronRight,
  Menu,
  X,
  Cpu,
  HardDrive as HardDriveIcon,
  Wifi,
  Thermometer,
  Box,
  Layers,
  Zap,
  Bot,
  Plus,
} from 'lucide-react';

const navigation = [
  { name: 'Dashboard', href: '/dashboard', icon: LayoutDashboard, badge: null },
  { name: 'Projetos', href: '/dashboard/projects', icon: FolderKanban, badge: '17' },
  { name: 'Deploy', href: '/dashboard/deploy', icon: Rocket, badge: null },
  { name: 'Bancos', href: '/dashboard/databases', icon: Database, badge: '5' },
  { name: 'Arquivos', href: '/dashboard/files', icon: FileText, badge: null },
  { name: 'Terminal', href: '/dashboard/terminal', icon: Terminal, badge: null },
  { name: 'Domínios', href: '/dashboard/domains', icon: Globe, badge: '12' },
  { name: 'Backups', href: '/dashboard/backups', icon: HardDrive, badge: '3' },
  { name: 'Logs', href: '/dashboard/logs', icon: FileText, badge: null },
  { name: 'Monitor', href: '/dashboard/monitor', icon: BarChart3, badge: null },
  { name: 'Marketplace', href: '/dashboard/marketplace', icon: Store, badge: '14' },
  { name: 'Agendamentos', href: '/dashboard/cron', icon: Zap, badge: '8' },
  { name: 'Usuários', href: '/dashboard/users', icon: Users, badge: '4' },
  { name: 'Estatísticas', href: '/dashboard/stats', icon: BarChart3, badge: null },
  { name: 'Notificações', href: '/dashboard/notifications', icon: Bell, badge: '3' },
  { name: 'Configurações', href: '/dashboard/settings', icon: Settings, badge: null },
];

const systemNavigation = [
  { name: 'Visão Geral', href: '/dashboard/system/overview', icon: LayoutDashboard },
  { name: 'CPU', href: '/dashboard/system/cpu', icon: Cpu },
  { name: 'Memória', href: '/dashboard/system/memory', icon: HardDriveIcon },
  { name: 'Rede', href: '/dashboard/system/network', icon: Wifi },
  { name: 'Disco', href: '/dashboard/system/disk', icon: HardDrive },
  { name: 'Docker', href: '/dashboard/system/docker', icon: Box },
  { name: 'Temperatura', href: '/dashboard/system/temp', icon: Thermometer },
];

interface SidebarProps {
  isOpen: boolean;
  onClose: () => void;
  onToggleCollapse: () => void;
  isCollapsed: boolean;
}

export function Sidebar({ isOpen, onClose, onToggleCollapse, isCollapsed }: SidebarProps) {
  const pathname = usePathname();
  const [activeSystem, setActiveSystem] = useState<string | null>(null);

  const isActive = (href: string) => pathname === href || pathname.startsWith(href + '/');

  return (
    <>
      <div
        className={cn(
          'fixed inset-0 bg-black/50 z-40 lg:hidden transition-opacity',
          isOpen ? 'opacity-100' : 'opacity-0 pointer-events-none'
        )}
        onClick={onClose}
        aria-hidden="true"
      />
      
      <aside
        className={cn(
          'fixed lg:sticky top-0 left-0 z-50 h-screen bg-bg-card border-r border-bg-border transition-all duration-300 ease-out flex flex-col',
          isCollapsed ? 'w-16' : 'w-64',
          isOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'
        )}
      >
        {!isCollapsed && (
          <div className="flex items-center justify-between h-16 px-4 border-b border-bg-border">
            <Link href="/dashboard" className="flex items-center gap-2">
              <div className="w-8 h-8 rounded-lg bg-primary flex items-center justify-center">
                <Zap className="w-5 h-5 text-white" />
              </div>
              <span className="font-bold text-lg text-text-primary">HADIX</span>
            </Link>
            <button
              onClick={onToggleCollapse}
              className="p-1.5 rounded-lg text-text-secondary hover:bg-bg-hover hover:text-text-primary transition-colors"
              aria-label="Recolher sidebar"
            >
              <ChevronLeft className="w-5 h-5" />
            </button>
          </div>
        )}

        {isCollapsed && (
          <div className="flex flex-col items-center pt-4 px-2">
            <Link href="/dashboard" className="p-2 rounded-lg text-text-secondary hover:bg-bg-hover hover:text-text-primary transition-colors" title="Dashboard">
              <Zap className="w-6 h-6" />
            </Link>
            <button
              onClick={onToggleCollapse}
              className="mt-4 p-1.5 rounded-lg text-text-secondary hover:bg-bg-hover hover:text-text-primary transition-colors"
              aria-label="Expandir sidebar"
            >
              <ChevronRight className="w-5 h-5" />
            </button>
          </div>
        )}

        <nav className="flex-1 overflow-y-auto px-2 py-4 space-y-1" role="navigation" aria-label="Navegação principal">
          {!isCollapsed && (
            <>
              <div className="px-3 py-2 text-xs font-medium text-text-muted uppercase tracking-wider">Principal</div>
              {navigation.map((item) => (
                <Link
                  key={item.name}
                  href={item.href}
                  className={cn(
                    'sidebar-link',
                    isActive(item.href) && 'sidebar-link-active'
                  )}
                  onClick={onClose}
                >
                  <item.icon className="w-5 h-5 flex-shrink-0" aria-hidden="true" />
                  <span className="truncate">{item.name}</span>
                  {item.badge && (
                    <span className="ml-auto badge badge-info">{item.badge}</span>
                  )}
                </Link>
              ))}
            </>
          )}

          {!isCollapsed && (
            <>
              <div className="h-px bg-bg-border my-2" />
              <div className="px-3 py-2 text-xs font-medium text-text-muted uppercase tracking-wider">Sistema</div>
              <div className="space-y-1">
                <button
                  onClick={() => setActiveSystem(activeSystem === 'system' ? null : 'system')}
                  className={cn(
                    'sidebar-link w-full text-left',
                    activeSystem === 'system' && 'sidebar-link-active'
                  )}
                >
                  <LayoutDashboard className="w-5 h-5 flex-shrink-0" />
                  <span className="truncate">VPS Monitor</span>
                  <ChevronRight 
                    className={cn(
                      'w-4 h-4 ml-auto flex-shrink-0 transition-transform',
                      activeSystem === 'system' && 'rotate-90'
                    )}
                  />
                </button>
                
                <AnimatePresence>
                  {activeSystem === 'system' && (
                    <motion.div
                      initial={{ opacity: 0, height: 0 }}
                      animate={{ opacity: 1, height: 'auto' }}
                      exit={{ opacity: 0, height: 0 }}
                      className="pl-10 space-y-0.5"
                    >
                      {systemNavigation.map((item) => (
                        <Link
                          key={item.name}
                          href={item.href}
                          className={cn('sidebar-link pl-2 text-sm', isActive(item.href) && 'sidebar-link-active')}
                          onClick={onClose}
                        >
                          <item.icon className="w-4 h-4 flex-shrink-0" />
                          <span className="truncate">{item.name}</span>
                        </Link>
                      ))}
                    </motion.div>
                  )}
                </AnimatePresence>
              </div>
            </>
          )}

          {!isCollapsed && (
            <>
              <div className="h-px bg-bg-border my-2" />
              <div className="px-3 py-2 text-xs font-medium text-text-muted uppercase tracking-wider">Projetos</div>
              <Link
                href="/dashboard/projects/new"
                className={cn('sidebar-link border border-primary/30 bg-primary/5')}
                onClick={onClose}
              >
                <Plus className="w-5 h-5 flex-shrink-0" />
                <span className="truncate">Novo Projeto</span>
              </Link>
            </>
          )}
        </nav>

        {!isCollapsed && (
          <div className="p-4 border-t border-bg-border">
            <div className="card p-3">
              <div className="flex items-center justify-between mb-2">
                <span className="text-sm font-medium text-text-primary">VPS Status</span>
                <span className="badge badge-success">Online</span>
              </div>
              <div className="space-y-2 text-xs">
                <div className="flex justify-between text-text-secondary">
                  <span>Uptime</span>
                  <span className="text-text-primary font-mono">99.99%</span>
                </div>
                <div className="flex justify-between text-text-secondary">
                  <span>Containers</span>
                  <span className="text-text-primary font-mono">8</span>
                </div>
                <div className="flex justify-between text-text-secondary">
                  <span>Projetos</span>
                  <span className="text-text-primary font-mono">17</span>
                </div>
              </div>
            </div>
          </div>
        )}
      </aside>
    </>
  );
}