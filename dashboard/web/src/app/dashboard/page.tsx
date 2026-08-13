'use client';

import { useState } from 'react';
import { cn } from '@/lib/utils';
import { Card, Badge, Progress } from '@/components/ui';
import { SystemChart } from '@/components/dashboard/SystemChart';
import { ProjectCard } from '@/components/dashboard/ProjectCard';
import { MetricCard } from '@/components/dashboard/MetricCard';
import {
  Zap,
  Cpu,
  MemoryStick,
  HardDrive,
  Wifi,
  Server,
  Box,
  Thermometer,
  FolderKanban,
  Database,
  Globe,
  HardDrive as HardDriveIcon,
  BarChart3,
  Store,
  Zap as ZapIcon,
  Users,
  Bell,
  Settings,
  TrendingUp,
  TrendingDown,
  Minus,
  Activity,
  AlertTriangle,
  CheckCircle,
  XCircle,
  Clock,
  ArrowUpRight,
  ArrowDownRight,
} from 'lucide-react';

const mockVPSMetrics = {
  cpu: 42,
  memory: { used: 3.1 * 1024 ** 3, total: 8 * 1024 ** 3 },
  disk: { used: 120 * 1024 ** 3, total: 500 * 1024 ** 3 },
  network: { up: 10 * 1024 ** 2, down: 32 * 1024 ** 2 },
  uptime: 86400 * 15 + 3600 * 4 + 1800,
  temperature: 45,
};

const mockProjects = [
  { name: 'Bot Discord', status: 'online' as const, cpu: '12%', ram: '245 MB / 512 MB', uptime: '15d 4h', domain: 'bot.meudominio.com', type: 'bot' as const },
  { name: 'API Principal', status: 'online' as const, cpu: '23%', ram: '512 MB / 1 GB', uptime: '15d 4h', domain: 'api.meudominio.com', type: 'api' as const },
  { name: 'Site Principal', status: 'offline' as const, cpu: '0%', ram: '0 MB / 256 MB', uptime: '0s', domain: 'meudominio.com', type: 'site' as const },
  { name: 'Minecraft Server', status: 'online' as const, cpu: '35%', ram: '2.1 GB / 4 GB', uptime: '8d 12h', domain: 'mc.meudominio.com', type: 'game' as const },
];

export default function DashboardPage() {
  const [activeTab, setActiveTab] = useState<'overview' | 'system' | 'projects'>('overview');

  return (
    <main className="min-h-screen bg-bg pb-8 p-4">
      <div className="max-w-7xl mx-auto">
        <header className="flex items-center justify-between mb-6 pb-4 border-b border-bg-border">
          <div>
            <h1 className="text-2xl font-bold text-text-primary">Painel HADIX</h1>
            <p className="text-text-secondary mt-1">Gerencie sua infraestrutura VPS e PaaS</p>
          </div>
          <div className="flex items-center gap-3">
            <Badge variant="success" dot>VPS Online</Badge>
            <span className="text-sm text-text-muted">Atualizado agora</span>
          </div>
        </header>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
          {[
            { label: 'CPU', value: `${mockVPSMetrics.cpu}%`, icon: <Cpu className="w-5 h-5" />, color: 'primary', progress: mockVPSMetrics.cpu },
            { label: 'RAM', value: `${formatBytes(mockVPSMetrics.memory.used)} / ${formatBytes(mockVPSMetrics.memory.total)}`, icon: <MemoryStick className="w-5 h-5" />, color: 'success', progress: (mockVPSMetrics.memory.used / mockVPSMetrics.memory.total) * 100 },
            { label: 'DISCO', value: `${formatBytes(mockVPSMetrics.disk.used)} / ${formatBytes(mockVPSMetrics.disk.total)}`, icon: <HardDrive className="w-5 h-5" />, color: 'danger', progress: (mockVPSMetrics.disk.used / mockVPSMetrics.disk.total) * 100 },
            { label: 'REDE', value: `↑ ${formatBytes(mockVPSMetrics.network.up)}/s ↓ ${formatBytes(mockVPSMetrics.network.down)}/s`, icon: <Wifi className="w-5 h-5" />, color: 'warning', progress: 45 },
          ].map((metric) => (
            <MetricCard
              key={metric.label}
              label={metric.label}
              value={metric.value}
              icon={metric.icon}
              color={metric.color as any}
              progress={metric.progress}
              trend={metric.progress >= 80 ? 'danger' : metric.progress >= 60 ? 'warning' : 'success'}
              trendUp={false}
              showProgress
            />
          ))}
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
          {[
            { label: 'Projetos', value: '17', icon: <FolderKanban className="w-5 h-5" />, color: 'primary', trend: '+3', trendUp: true },
            { label: 'Deploys', value: '321', icon: <Zap className="w-5 h-5" />, color: 'success', trend: '+12', trendUp: true },
            { label: 'Uptime', value: '99.99%', icon: <Activity className="w-5 h-5" />, color: 'info', trend: 'Estável', trendUp: true },
            { label: 'Containers', value: '8', icon: <Box className="w-5 h-5" />, color: 'warning', trend: '+1', trendUp: false },
          ].map((stat) => (
            <MetricCard
              key={stat.label}
              label={stat.label}
              value={stat.value}
              icon={stat.icon}
              color={stat.color as any}
              trend={stat.trend}
              trendUp={stat.trendUp}
            />
          ))}
        </div>

        <div className="grid lg:grid-cols-2 gap-6">
          <div className="space-y-6">
            <div className="flex items-center justify-between">
              <h3 className="text-lg font-semibold text-text-primary">Visão Geral</h3>
              <div className="flex gap-2">
                <button
                  className={cn(
                    'flex-1 rounded-md text-sm font-medium text-text-primary py-2 px-4 transition-all duration-200',
                    activeTab === 'overview' && 'bg-primary text-white'
                  )}
                  onClick={() => setActiveTab('overview')}
                >
                  Visão Geral
                </button>
                <button
                  className={cn(
                    'flex-1 rounded-md text-sm font-medium text-text-secondary py-2 px-4 hover:text-text-primary hover:bg-bg-hover transition-all duration-200',
                    activeTab === 'overview' && 'bg-primary text-white'
                  )}
                  onClick={() => setActiveTab('overview')}
                >
                  Sistema
                </button>
                <button
                  className={cn(
                    'flex-1 rounded-md text-sm font-medium text-text-secondary py-2 px-4 hover:text-text-primary hover:bg-bg-hover transition-all duration-200',
                    activeTab === 'projects' && 'bg-primary text-white'
                  )}
                  onClick={() => setActiveTab('projects')}
                >
                  Projetos
                </button>
              </div>
            </div>

            <AnimatePresence mode="wait">
              {activeTab === 'overview' && (
                <motion-div
                  key="overview"
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, y: -10 }}
                  transition={{ duration: 0.2 }}
                  className="space-y-6"
                >
                  <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                    <Card>
                      <div className="flex items-center justify-between mb-4">
                        <h3 className="text-lg font-semibold text-text-primary">CPU</h3>
                        <Badge variant="info">{mockVPSMetrics.cpu}%</Badge>
                      </div>
                      <SystemChart type="cpu" height={250} />
                      <div className="mt-4 grid grid-cols-3 gap-4 text-center">
                        <div>
                          <p className="text-2xl font-bold text-text-primary">42%</p>
                          <p className="text-xs text-text-muted">Uso Atual</p>
                        </div>
                        <div>
                          <p className="text-2xl font-bold text-text-primary">2.4 GHz</p>
                          <p className="text-xs text-text-muted">Frequência</p>
                        </div>
                        <div>
                          <p className="text-2xl font-bold text-text-primary">{mockVPSMetrics.temperature}°C</p>
                          <p className="text-xs text-text-muted">Temperatura</p>
                        </div>
                      </div>
                    </Card>

                    <Card>
                      <div className="flex items-center justify-between mb-4">
                        <h3 className="text-lg font-semibold text-text-primary">Memória RAM</h3>
                        <Badge variant="success">{(mockVPSMetrics.memory.used / mockVPSMetrics.memory.total * 100).toFixed(1)}%</Badge>
                      </div>
                      <SystemChart type="memory" height={250} />
                      <div className="mt-4 grid grid-cols-3 gap-4 text-center">
                        <div>
                          <p className="text-2xl font-bold text-text-primary">{formatBytes(mockVPSMetrics.memory.used)}</p>
                          <p className="text-xs text-text-muted">Usado</p>
                        </div>
                        <div>
                          <p className="text-2xl font-bold text-text-primary">{formatBytes(mockVPSMetrics.memory.total)}</p>
                          <p className="text-xs text-text-muted">Total</p>
                        </div>
                        <div>
                          <p className="text-2xl font-bold text-text-primary">{formatBytes(mockVPSMetrics.memory.total - mockVPSMetrics.memory.used)}</p>
                          <p className="text-xs text-text-muted">Livre</p>
                        </div>
                      </div>
                    </Card>
                  </div>

                  <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                    <Card>
                      <div className="flex items-center justify-between mb-4">
                        <h3 className="text-lg font-semibold text-text-primary">Rede</h3>
                        <Badge variant="warning">Ativa</Badge>
                      </div>
                      <SystemChart type="network" height={250} />
                      <div className="mt-4 grid grid-cols-4 gap-4 text-center">
                        <div className="text-success">
                          <p className="text-lg font-bold">↑ {formatBytes(mockVPSMetrics.network.up)}/s</p>
                          <p className="text-xs text-text-muted">Upload</p>
                        </div>
                        <div className="text-primary">
                          <p className="text-lg font-bold">↓ {formatBytes(mockVPSMetrics.network.down)}/s</p>
                          <p className="text-xs text-text-muted">Download</p>
                        </div>
                        <div>
                          <p className="text-lg font-bold text-text-primary">12.4 MB</p>
                          <p className="text-xs text-text-muted">Enviado (1h)</p>
                        </div>
                        <div>
                          <p className="text-lg font-bold text-text-primary">45.2 MB</p>
                          <p className="text-xs text-text-muted">Recebido (1h)</p>
                        </div>
                      </div>
                    </Card>

                    <Card>
                      <div className="flex items-center justify-between mb-4">
                        <h3 className="text-lg font-semibold text-text-primary">Disco</h3>
                        <Badge variant="danger">{(mockVPSMetrics.disk.used / mockVPSMetrics.disk.total * 100).toFixed(1)}%</Badge>
                      </div>
                      <SystemChart type="disk" height={250} />
                      <div className="mt-4 grid grid-cols-3 gap-4 text-center">
                        <div>
                          <p className="text-2xl font-bold text-text-primary">{formatBytes(mockVPSMetrics.disk.used)}</p>
                          <p className="text-xs text-text-muted">Usado</p>
                        </div>
                        <div>
                          <p className="text-2xl font-bold text-text-primary">{formatBytes(mockVPSMetrics.disk.total)}</p>
                          <p className="text-xs text-text-muted">Total</p>
                        </div>
                        <div>
                          <p className="text-2xl font-bold text-text-primary">{formatBytes(mockVPSMetrics.disk.total - mockVPSMetrics.disk.used)}</p>
                          <p className="text-xs text-text-muted">Livre</p>
                        </div>
                      </div>
                    </Card>
                  </div>
                </motion-div>
              )}

              {activeTab === 'system' && (
                <motion-div
                  key="system"
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, y: -10 }}
                  transition={{ duration: 0.2 }}
                  className="grid grid-cols-1 lg:grid-cols-2 gap-6"
                >
                  <Card>
                    <h3 className="text-lg font-semibold text-text-primary mb-4">Temperatura</h3>
                    <div className="space-y-4">
                      {[{ name: 'CPU Package', temp: 45, max: 90 }, { name: 'CPU Core 0', temp: 42, max: 90 }, { name: 'CPU Core 1', temp: 43, max: 90 }, { name: 'NVMe SSD', temp: 38, max: 70 }, { name: 'GPU', temp: 35, max: 85 }].map((sensor) => (
                        <div key={sensor.name} className="flex items-center justify-between">
                          <div className="flex items-center gap-3">
                            <Thermometer className="w-5 h-5 text-text-muted" />
                            <div>
                              <p className="text-sm font-medium text-text-primary">{sensor.name}</p>
                              <p className="text-xs text-text-muted">Máx: {sensor.max}°C</p>
                            </div>
                          </div>
                          <div className="flex items-center gap-3 w-48">
                            <Progress value={sensor.temp} max={sensor.max} color={sensor.temp > sensor.max * 0.8 ? 'danger' : sensor.temp > sensor.max * 0.6 ? 'warning' : 'success'} size="sm" showLabel />
                          </div>
                          <span className={cn('font-mono font-medium', sensor.temp > sensor.max * 0.8 ? 'text-danger' : 'text-text-primary')}>
                            {sensor.temp}°C
                          </span>
                        </div>
                      ))}
                    </div>
                  </Card>

                  <Card className="lg:col-span-2">
                    <h3 className="text-lg font-semibold text-text-primary mb-4">Docker Containers</h3>
                    <div className="space-y-3">
                      {[{ name: 'bot-discord', status: 'running', cpu: '12%', mem: '245 MB', ports: '3000', image: 'node:20-alpine' }, { name: 'api-main', status: 'running', cpu: '23%', mem: '512 MB', ports: '8000', image: 'node:20-alpine' }, { name: 'site-main', status: 'exited', cpu: '0%', mem: '0 MB', ports: '80', image: 'nginx:alpine' }, { name: 'minecraft-server', status: 'running', cpu: '35%', mem: '2.1 GB', ports: '25565', image: 'itzg/minecraft-server' }, { name: 'mongodb', status: 'running', cpu: '2%', mem: '180 MB', ports: '27017', image: 'mongo:7' }, { name: 'redis', status: 'running', cpu: '1%', mem: '45 MB', ports: '6379', image: 'redis:7-alpine' }, { name: 'postgres', status: 'running', cpu: '3%', mem: '320 MB', ports: '5432', image: 'postgres:15' }, { name: 'nginx-proxy', status: 'running', cpu: '1%', mem: '25 MB', ports: '80,443', image: 'nginx:alpine' }].map((container) => (
                        <div key={container.name} className="flex items-center justify-between p-3 bg-bg border border-bg-border rounded-lg">
                          <div className="flex items-center gap-3">
                            <div className={cn('w-2 h-2 rounded-full', container.status === 'running' ? 'bg-success' : 'bg-danger')} />
                            <div>
                              <p className="font-mono text-sm text-text-primary">{container.name}</p>
                              <p className="text-xs text-text-muted">{container.image}</p>
                            </div>
                          </div>
                          <div className="flex items-center gap-4 text-sm text-text-secondary">
                            <span><Cpu className="w-3 h-3 inline mr-1" /> {container.cpu}</span>
                            <span><MemoryStick className="w-3 h-3 inline mr-1" /> {container.mem}</span>
                            <span className="font-mono text-xs">{container.ports}</span>
                          </div>
                        </div>
                      ))}
                    </div>
                  </Card>
                </motion-div>
              )}

              {activeTab === 'projects' && (
                <motion-div
                  key="projects"
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, y: -10 }}
                  transition={{ duration: 0.2 }}
                  className="space-y-4"
                >
                  <div className="flex items-center justify-between">
                    <h3 className="text-lg font-semibold text-text-primary">Seus Projetos</h3>
                    <Button asChild>
                      <Link href="/dashboard/projects/new">
                        <Plus className="w-4 h-4 mr-2" /> Novo Projeto
                      </Link>
                    </Button>
                  </div>
                  <div className="grid grid-cols-1 gap-4">
                    {mockProjects.map((project) => (
                      <ProjectCard key={project.name} project={project} />
                    ))}
                  </div>
                </motion-div>
              )}
            </AnimatePresence>
          </div>

          <div className="space-y-6">
            <Card>
              <h3 className="text-lg font-semibold text-text-primary mb-4 flex items-center gap-2">
                <Server className="w-5 h-5 text-primary" />
                Informações da VPS
              </h3>
              <div className="space-y-3">
                <div className="flex justify-between text-sm">
                  <span className="text-text-secondary">Hostname</span>
                  <span className="text-text-primary font-mono">hadix-vps-01</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-text-secondary">IP Público</span>
                  <span className="text-text-primary font-mono">203.0.113.42</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-text-secondary">IP Privado</span>
                  <span className="text-text-primary font-mono">10.0.0.5</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-text-secondary">SO</span>
                  <span className="text-text-primary">Ubuntu 22.04 LTS</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-text-secondary">Kernel</span>
                  <span className="text-text-primary font-mono">6.5.0-1016-oracle</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-text-secondary">Uptime</span>
                  <span className="text-text-primary font-mono">{formatUptime(mockVPSMetrics.uptime)}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-text-secondary">Docker</span>
                  <span className="text-text-primary font-mono">24.0.7</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-text-secondary">PM2</span>
                  <span className="text-text-primary font-mono">5.3.1</span>
                </div>
              </div>
            </Card>

            <Card>
              <div className="flex items-center justify-between mb-4">
                <h3 className="text-lg font-semibold text-text-primary flex items-center gap-2">
                  <Activity className="w-5 h-5" />
                  Atividade Recente
                </h3>
                <Button variant="ghost" size="sm" asChild>
                  <Link href="/dashboard/logs">Ver todos</Link>
                </Button>
              </div>
              <div className="space-y-3">
                {recentActivity.map((activity, index) => (
                  <div key={index} className="p-3 bg-bg border border-bg-border rounded-lg hover:bg-bg-hover transition-colors">
                    <div className={cn(
                      'w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0',
                      activity.status === 'success' && 'bg-success/10 text-success',
                      activity.status === 'warning' && 'bg-warning/10 text-warning',
                      activity.status === 'error' && 'bg-danger/10 text-danger',
                      activity.status === 'info' && 'bg-primary/10 text-primary',
                    )}>
                      {activity.status === 'success' && <CheckCircle className="w-4 h-4" />}
                      {activity.status === 'warning' && <AlertTriangle className="w-4 h-4" />}
                      {activity.status === 'error' && <XCircle className="w-4 h-4" />}
                      {activity.status === 'info' && <Activity className="w-4 h-4" />}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-medium text-text-primary">{activity.title}</p>
                      <p className="text-xs text-text-muted">{activity.description}</p>
                    </div>
                    <span className="text-xs text-text-muted whitespace-nowrap">{activity.time}</span>
                  </div>
                ))}
              </div>
            </Card>

            <Card>
              <h3 className="text-lg font-semibold text-text-primary mb-4">Ações Rápidas</h3>
              <div className="grid grid-cols-2 gap-3">
                {[{ label: 'Novo Deploy', icon: <ZapIcon className="w-5 h-5" />, href: '/dashboard/deploy', color: 'primary' }, { label: 'Criar Banco', icon: <Database className="w-5 h-5" />, href: '/dashboard/databases/new', color: 'success' }, { label: 'Adicionar Domínio', icon: <Globe className="w-5 h-5" />, href: '/dashboard/domains/new', color: 'warning' }, { label: 'Backup Manual', icon: <HardDriveIcon className="w-5 h-5" />, href: '/dashboard/backups/new', color: 'danger' }, { label: 'Abrir Terminal', icon: <Terminal className="w-5 h-5" />, href: '/dashboard/terminal', color: 'info' }, { label: 'Marketplace', icon: <Store className="w-5 h-5" />, href: '/dashboard/marketplace', color: 'purple' },].map((action) => (
                  <Link
                    key={action.label}
                    href={action.href}
                    className={cn(
                      'card p-4 flex flex-col items-center justify-center gap-2 text-center transition-all',
                      'hover:border-primary/30 hover:bg-primary/5'
                    )}
                  >
                    <div className={cn('p-2 rounded-lg', `${action.color}/10 text-${action.color}`)}>
                      {action.icon}
                    </div>
                    <span className="text-sm font-medium text-text-primary">{action.label}</span>
                  </Link>
                ))}
              </div>
            </Card>
          </div>
        </div>
      </div>
    </main>
  );
}