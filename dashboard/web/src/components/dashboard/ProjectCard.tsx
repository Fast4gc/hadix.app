'use client';

import { ReactNode } from 'react';
import Link from 'next/link';
import { cn, getStatusColor, getStatusBadge } from '@/lib/utils';
import { Card } from '@/components/ui/Card';
import { Badge } from '@/components/ui/Badge';
import { Button } from '@/components/ui/Button';
import { Progress } from '@/components/ui/Progress';
import {
  Cpu,
  MemoryStick,
  Clock,
  Globe,
  Play,
  Square,
  Trash2,
  Settings,
  MoreVertical,
  DropdownMenu,
  DropdownMenuTrigger,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
} from 'lucide-react';

interface ProjectCardProps {
  project: {
    name: string;
    status: 'online' | 'offline' | 'warning' | 'error' | 'starting' | 'stopping';
    cpu: string;
    ram: string;
    uptime: string;
    domain?: string;
    type: 'bot' | 'api' | 'site' | 'worker' | 'game' | 'database';
    port?: number;
    containerId?: string;
  };
  compact?: boolean;
}

const typeIcons = {
  bot: Bot,
  api: Server,
  site: Globe,
  worker: Cpu,
  game: Gamepad2,
  database: Database,
};

const typeColors = {
  bot: 'text-primary',
  api: 'text-success',
  site: 'text-warning',
  worker: 'text-info',
  game: 'text-danger',
  database: 'text-purple',
};

import { Bot, Server, Globe, Cpu, Gamepad2, Database } from 'lucide-react';

export function ProjectCard({ project, compact = false }: ProjectCardProps) {
  const TypeIcon = typeIcons[project.type];
  const statusColor = getStatusColor(project.status);
  const statusBadge = getStatusBadge(project.status);

  const cpuValue = parseFloat(project.cpu.replace('%', ''));
  const ramValue = project.ram;

  return (
    <div className={cn('group', compact ? 'p-4' : 'p-4 hover:bg-bg-hover rounded-lg transition-colors')}>
      <div className="flex items-start justify-between gap-4">
        <div className="flex items-center gap-3 min-w-0 flex-1">
          <div className={cn('p-2 rounded-lg bg-bg border border-bg-border flex-shrink-0', typeColors[project.type] + '/10')}>
            <TypeIcon className={cn('w-5 h-5', typeColors[project.type])} />
          </div>
          <div className="min-w-0">
            <div className="flex items-center gap-2">
              <h4 className="font-medium text-text-primary truncate">{project.name}</h4>
              <Badge variant={statusBadge} dot>{project.status}</Badge>
            </div>
            {project.domain && (
              <p className="text-xs text-text-muted truncate mt-0.5 flex items-center gap-1">
                <Globe className="w-3 h-3" />
                {project.domain}
              </p>
            )}
          </div>
        </div>

        {!compact && (
          <div className="flex items-center gap-1 flex-shrink-0">
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <button className="p-1.5 rounded-lg text-text-muted hover:bg-bg-hover hover:text-text-primary transition-colors">
                  <MoreVertical className="w-4 h-4" />
                </button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end" className="dropdown w-40">
                <DropdownMenuItem asChild>
                  <Link href={`/dashboard/projects/${project.name}`} className="dropdown-item w-full">
                    <Settings className="w-4 h-4" /> Visão Geral
                  </Link>
                </DropdownMenuItem>
                <DropdownMenuItem asChild>
                  <Link href={`/dashboard/projects/${project.name}/deploy`} className="dropdown-item w-full">
                    <Upload className="w-4 h-4" /> Deploy
                  </Link>
                </DropdownMenuItem>
                <DropdownMenuItem asChild>
                  <Link href={`/dashboard/projects/${project.name}/logs`} className="dropdown-item w-full">
                    <FileText className="w-4 h-4" /> Logs
                  </Link>
                </DropdownMenuItem>
                <DropdownMenuItem asChild>
                  <Link href={`/dashboard/projects/${project.name}/terminal`} className="dropdown-item w-full">
                    <Terminal className="w-4 h-4" /> Terminal
                  </Link>
                </DropdownMenuItem>
                <DropdownMenuItem asChild>
                  <Link href={`/dashboard/projects/${project.name}/files`} className="dropdown-item w-full">
                    <FolderOpen className="w-4 h-4" /> Arquivos
                  </Link>
                </DropdownMenuItem>
                <DropdownMenuSeparator />
                <DropdownMenuItem className="dropdown-item w-full text-danger flex items-center justify-start">
                  <Square className="w-4 h-4" /> Parar
                </DropdownMenuItem>
                <DropdownMenuItem className="dropdown-item w-full text-danger flex items-center justify-start">
                  <Trash2 className="w-4 h-4" /> Excluir
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          </div>
        )}
      </div>

      {!compact && (
        <div className="mt-4 grid grid-cols-3 gap-3">
          <div className="bg-bg border border-bg-border rounded-lg p-3">
            <div className="flex items-center gap-1.5 text-xs text-text-muted mb-1">
              <Cpu className="w-3 h-3" />
              <span>CPU</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-sm font-mono text-text-primary">{project.cpu}</span>
              <Progress value={cpuValue} max={100} color="primary" size="sm" className="w-24" />
            </div>
          </div>

          <div className="bg-bg border border-bg-border rounded-lg p-3">
            <div className="flex items-center gap-1.5 text-xs text-text-muted mb-1">
              <MemoryStick className="w-3 h-3" />
              <span>RAM</span>
            </div>
            <span className="text-sm font-mono text-text-primary">{ramValue}</span>
          </div>

          <div className="bg-bg border border-bg-border rounded-lg p-3">
            <div className="flex items-center gap-1.5 text-xs text-text-muted mb-1">
              <Clock className="w-3 h-3" />
              <span>Uptime</span>
            </div>
            <span className="text-sm font-mono text-text-primary">{project.uptime}</span>
          </div>
        </div>
      )}

      {!compact && (
        <div className="mt-4 flex items-center gap-2 pt-4 border-t border-bg-border">
          <Button variant="ghost" size="sm" className="flex-1" asChild>
            <Link href={`/dashboard/projects/${project.name}`}>
              <Settings className="w-4 h-4 mr-1" /> Configurar
            </Link>
          </Button>
          <Button variant="ghost" size="sm" className="flex-1" onClick={() => {}}>
            {project.status === 'online' ? (
              <>
                <Square className="w-4 h-4 mr-1" /> Parar
              </>
            ) : (
              <>
                <Play className="w-4 h-4 mr-1" /> Iniciar
              </>
            )}
          </Button>
          <Button variant="ghost" size="sm" className="flex-1" onClick={() => {}}>
            <RotateCcw className="w-4 h-4 mr-1" /> Restart
          </Button>
        </div>
      )}
    </div>
  );
}

import { RotateCcw, Upload, FileText, Terminal, FolderOpen, Square, Play, MoreVertical, MemoryStick, Clock, Globe, Settings, Trash2 } from 'lucide-react';
import { DropdownMenu, DropdownMenuTrigger, DropdownMenuContent, DropdownMenuItem, DropdownMenuSeparator } from '@/components/ui/DropdownMenu';