'use client';

import { useState, useRef, useEffect } from 'react';
import Link from 'next/link';
import { motion, AnimatePresence } from 'framer-motion';
import { cn } from '@/lib/utils';
import {
  Menu,
  Bell,
  Search,
  ChevronDown,
  LogOut,
  User,
  Settings,
  Moon,
  Sun,
  HelpCircle,
  Shield,
  Zap,
  X,
} from 'lucide-react';
import { Avatar } from '@/components/ui/Avatar';

interface HeaderProps {
  onMenuClick: () => void;
  isSidebarCollapsed: boolean;
  onToggleSidebarCollapse: () => void;
}

export function Header({ onMenuClick, isSidebarCollapsed, onToggleSidebarCollapse }: HeaderProps) {
  const [showNotifications, setShowNotifications] = useState(false);
  const [showUserMenu, setShowUserMenu] = useState(false);
  const [showSearch, setShowSearch] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const notificationsRef = useRef<HTMLDivElement>(null);
  const userMenuRef = useRef<HTMLDivElement>(null);
  const searchRef = useRef<HTMLDivElement>(null);

  const notifications = [
    { id: 1, type: 'deploy', title: 'Deploy concluído', message: 'Bot Discord deployado com sucesso', time: '2 min atrás', read: false },
    { id: 2, type: 'alert', title: 'Alerta de RAM', message: 'Uso de RAM acima de 90% na VPS principal', time: '15 min atrás', read: false },
    { id: 3, type: 'backup', title: 'Backup finalizado', message: 'Backup diário completo restaurado', time: '1 hora atrás', read: true },
    { id: 4, type: 'deploy', title: 'Deploy falhou', message: 'Erro no build do projeto API', time: '3 horas atrás', read: true },
  ];

  const unreadCount = notifications.filter(n => !n.read).length;

  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (notificationsRef.current && !notificationsRef.current.contains(event.target as Node)) {
        setShowNotifications(false);
      }
      if (userMenuRef.current && !userMenuRef.current.contains(event.target as Node)) {
        setShowUserMenu(false);
      }
      if (searchRef.current && !searchRef.current.contains(event.target as Node)) {
        setShowSearch(false);
      }
    }
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const getNotificationIcon = (type: string) => {
    switch (type) {
      case 'deploy': return <Rocket className="w-4 h-4 text-primary" />;
      case 'alert': return <Shield className="w-4 h-4 text-danger" />;
      case 'backup': return <Zap className="w-4 h-4 text-success" />;
      default: return <Bell className="w-4 h-4 text-primary" />;
    }
  };

  return (
    <header className={cn(
      'sticky top-0 z-30 bg-bg/80 backdrop-blur-xl border-b border-bg-border transition-all duration-300',
      isSidebarCollapsed ? 'lg:ml-16' : 'lg:ml-64'
    )}>
      <div className="flex items-center justify-between h-16 px-4 lg:px-6">
        <div className="flex items-center gap-4">
          <button
            onClick={onMenuClick}
            className="lg:hidden p-2 rounded-lg text-text-secondary hover:bg-bg-hover hover:text-text-primary transition-colors"
            aria-label="Abrir menu"
          >
            <Menu className="w-6 h-6" />
          </button>

          <button
            onClick={onToggleSidebarCollapse}
            className="hidden lg:flex p-2 rounded-lg text-text-secondary hover:bg-bg-hover hover:text-text-primary transition-colors"
            aria-label={isSidebarCollapsed ? 'Expandir sidebar' : 'Recolher sidebar'}
          >
            {isSidebarCollapsed ? <ChevronRight className="w-5 h-5" /> : <ChevronLeft className="w-5 h-5" />}
          </button>

          <div className={cn('relative', showSearch ? 'w-96' : 'hidden lg:block')}>
            <div className="relative" ref={searchRef}>
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-text-muted" />
              <input
                type="text"
                placeholder="Buscar projetos, domínios, logs..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                onFocus={() => setShowSearch(true)}
                onBlur={() => setTimeout(() => setShowSearch(false), 200)}
                className="input pl-10 pr-10 w-full"
              />
              {searchQuery && (
                <button
                  onClick={() => setSearchQuery('')}
                  className="absolute right-3 top-1/2 -translate-y-1/2 p-1 text-text-muted hover:text-text-primary"
                >
                  <X className="w-4 h-4" />
                </button>
              )}
            </div>
            
            <AnimatePresence>
              {showSearch && searchQuery && (
                <motion.div
                  initial={{ opacity: 0, y: -10 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, y: -10 }}
                  className="absolute top-full left-0 right-0 mt-2 bg-bg-card border border-bg-border rounded-card shadow-card-hover p-2 z-50"
                >
                  <div className="px-2 py-1 text-xs font-medium text-text-muted uppercase tracking-wider">Resultados</div>
                  <div className="space-y-1 max-h-60 overflow-y-auto">
                    <Link href="/dashboard/projects/bot-discord" className="dropdown-item">
                      <Bot className="w-4 h-4" /> Bot Discord
                    </Link>
                    <Link href="/dashboard/projects/api" className="dropdown-item">
                      <Server className="w-4 h-4" /> API Principal
                    </Link>
                    <Link href="/dashboard/projects/site" className="dropdown-item">
                      <Globe className="w-4 h-4" /> Site Principal
                    </Link>
                    <Link href="/dashboard/domains" className="dropdown-item">
                      <Globe className="w-4 h-4" /> Domínios
                    </Link>
                  </div>
                </motion.div>
              )}
            </AnimatePresence>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <div className="relative" ref={notificationsRef}>
            <button
              onClick={() => setShowNotifications(!showNotifications)}
              className="relative p-2 rounded-lg text-text-secondary hover:bg-bg-hover hover:text-text-primary transition-colors"
              aria-label="Notificações"
            >
              <Bell className="w-5 h-5" />
              {unreadCount > 0 && (
                <span className="absolute -top-1 -right-1 w-5 h-5 bg-danger text-white text-xs font-medium rounded-full flex items-center justify-center">
                  {unreadCount > 9 ? '9+' : unreadCount}
                </span>
              )}
            </button>

            <AnimatePresence>
              {showNotifications && (
                <motion.div
                  initial={{ opacity: 0, y: -10 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, y: -10 }}
                  className="dropdown w-96"
                >
                  <div className="flex items-center justify-between px-3 py-2 border-b border-bg-border">
                    <span className="text-sm font-medium text-text-primary">Notificações</span>
                    {unreadCount > 0 && (
                      <button className="text-xs text-primary hover:text-primary-hover">Marcar todas como lidas</button>
                    )}
                  </div>
                  <div className="max-h-80 overflow-y-auto">
                    {notifications.length === 0 ? (
                      <div className="px-3 py-6 text-center text-text-secondary">Nenhuma notificação</div>
                    ) : (
                      notifications.map((notification) => (
                        <Link
                          key={notification.id}
                          href="#"
                          className={cn(
                            'dropdown-item p-3 gap-3',
                            !notification.read && 'bg-primary/5'
                          )}
                        >
                          <div className="w-8 h-8 rounded-lg bg-bg-border flex items-center justify-center flex-shrink-0">
                            {getNotificationIcon(notification.type)}
                          </div>
                          <div className="flex-1 min-w-0">
                            <p className={cn('text-sm font-medium', !notification.read ? 'text-text-primary' : 'text-text-secondary')}>
                              {notification.title}
                            </p>
                            <p className="text-xs text-text-muted truncate">{notification.message}</p>
                          </div>
                          <span className="text-xs text-text-muted whitespace-nowrap">{notification.time}</span>
                        </Link>
                      ))
                    )}
                  </div>
                  <div className="border-t border-bg-border p-3">
                    <Link href="/dashboard/notifications" className="dropdown-item w-full justify-center">
                      Ver todas as notificações
                    </Link>
                  </div>
                </motion.div>
              )}
            </AnimatePresence>
          </div>

          <div className="relative" ref={userMenuRef}>
            <button
              onClick={() => setShowUserMenu(!showUserMenu)}
              className="flex items-center gap-2 p-1.5 rounded-lg hover:bg-bg-hover transition-colors"
              aria-label="Menu do usuário"
            >
              <Avatar
                src="/avatar.png"
                fallback="MA"
                size="sm"
              />
              <span className="hidden lg:block text-sm font-medium text-text-primary">Martins</span>
              <ChevronDown className="w-4 h-4 text-text-muted lg:hidden" />
            </button>

            <AnimatePresence>
              {showUserMenu && (
                <motion.div
                  initial={{ opacity: 0, y: -10 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, y: -10 }}
                  className="dropdown w-56"
                >
                  <div className="px-3 py-2 border-b border-bg-border">
                    <p className="text-sm font-medium text-text-primary">Martins</p>
                    <p className="text-xs text-text-muted">admin@hadix.app</p>
                  </div>
                  <Link href="/dashboard/profile" className="dropdown-item">
                    <User className="w-4 h-4" /> Perfil
                  </Link>
                  <Link href="/dashboard/settings" className="dropdown-item">
                    <Settings className="w-4 h-4" /> Configurações
                  </Link>
                  <Link href="/dashboard/settings/security" className="dropdown-item">
                    <Shield className="w-4 h-4" /> Segurança
                  </Link>
                  <div className="h-px bg-bg-border my-1" />
                  <Link href="/docs" target="_blank" rel="noopener" className="dropdown-item">
                    <HelpCircle className="w-4 h-4" /> Documentação
                  </Link>
                  <div className="h-px bg-bg-border my-1" />
                  <button className="dropdown-item w-full text-danger justify-start">
                    <LogOut className="w-4 h-4" /> Sair
                  </button>
                </motion.div>
              )}
            </AnimatePresence>
          </div>
        </div>
      </div>
    </header>
  );
}

// Import missing icons
import { Bot, Server, Globe, LogOut, Settings, HelpCircle, ChevronRight, ChevronLeft } from 'lucide-react';