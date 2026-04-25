import { Injectable } from '@nestjs/common';

type MetricLabels = Record<string, string | number | boolean | undefined>;

interface CounterMetric {
  readonly type: 'counter';
  readonly help: string;
  readonly values: Map<string, number>;
  readonly labelsByKey: Map<string, Record<string, string>>;
}

interface GaugeMetric {
  readonly type: 'gauge';
  readonly help: string;
  readonly values: Map<string, number>;
  readonly labelsByKey: Map<string, Record<string, string>>;
}

interface SummaryValue {
  count: number;
  sum: number;
  max: number;
}

interface SummaryMetric {
  readonly type: 'summary';
  readonly help: string;
  readonly values: Map<string, SummaryValue>;
  readonly labelsByKey: Map<string, Record<string, string>>;
}

type RegisteredMetric = CounterMetric | GaugeMetric | SummaryMetric;

@Injectable()
export class MetricsRegistryService {
  private readonly metrics = new Map<string, RegisteredMetric>();

  incrementCounter(
    name: string,
    options: {
      help: string;
      value?: number;
      labels?: MetricLabels;
    },
  ): void {
    const metric = this.getOrCreateCounter(name, options.help);
    const normalizedLabels = this.normalizeLabels(options.labels);
    const key = this.serializeLabels(normalizedLabels);
    const currentValue = metric.values.get(key) ?? 0;

    metric.values.set(key, currentValue + (options.value ?? 1));
    metric.labelsByKey.set(key, normalizedLabels);
  }

  setGauge(
    name: string,
    options: {
      help: string;
      value: number;
      labels?: MetricLabels;
    },
  ): void {
    const metric = this.getOrCreateGauge(name, options.help);
    const normalizedLabels = this.normalizeLabels(options.labels);
    const key = this.serializeLabels(normalizedLabels);

    metric.values.set(key, options.value);
    metric.labelsByKey.set(key, normalizedLabels);
  }

  observeSummary(
    name: string,
    options: {
      help: string;
      value: number;
      labels?: MetricLabels;
    },
  ): void {
    const metric = this.getOrCreateSummary(name, options.help);
    const normalizedLabels = this.normalizeLabels(options.labels);
    const key = this.serializeLabels(normalizedLabels);
    const currentValue = metric.values.get(key) ?? {
      count: 0,
      sum: 0,
      max: 0,
    };

    currentValue.count += 1;
    currentValue.sum += options.value;
    currentValue.max = Math.max(currentValue.max, options.value);
    metric.values.set(key, currentValue);
    metric.labelsByKey.set(key, normalizedLabels);
  }

  renderPrometheus(): string {
    const lines: string[] = [];

    for (const [name, metric] of this.metrics.entries()) {
      if (metric.type === 'counter' || metric.type === 'gauge') {
        lines.push(`# HELP ${name} ${metric.help}`);
        lines.push(`# TYPE ${name} ${metric.type}`);

        for (const [key, value] of metric.values.entries()) {
          lines.push(
            `${name}${this.formatLabels(metric.labelsByKey.get(key))} ${value}`,
          );
        }

        continue;
      }

      lines.push(`# HELP ${name} ${metric.help}`);
      lines.push(`# TYPE ${name} summary`);

      for (const [key, value] of metric.values.entries()) {
        const labels = metric.labelsByKey.get(key);
        lines.push(
          `${name}_count${this.formatLabels(labels)} ${value.count}`,
          `${name}_sum${this.formatLabels(labels)} ${value.sum}`,
          `${name}_max${this.formatLabels(labels)} ${value.max}`,
        );
      }
    }

    return lines.join('\n');
  }

  getSnapshot(): Record<string, unknown> {
    const snapshot: Record<string, unknown> = {};

    for (const [name, metric] of this.metrics.entries()) {
      if (metric.type === 'summary') {
        snapshot[name] = Array.from(metric.values.entries()).map(([key, value]) => ({
          labels: metric.labelsByKey.get(key) ?? {},
          ...value,
        }));
        continue;
      }

      snapshot[name] = Array.from(metric.values.entries()).map(([key, value]) => ({
        labels: metric.labelsByKey.get(key) ?? {},
        value,
      }));
    }

    return snapshot;
  }

  private getOrCreateCounter(name: string, help: string): CounterMetric {
    const existing = this.metrics.get(name);

    if (existing != null) {
      if (existing.type !== 'counter') {
        throw new Error(`Metric ${name} already registered as ${existing.type}`);
      }

      return existing;
    }

    const created: CounterMetric = {
      type: 'counter',
      help,
      values: new Map(),
      labelsByKey: new Map(),
    };
    this.metrics.set(name, created);
    return created;
  }

  private getOrCreateGauge(name: string, help: string): GaugeMetric {
    const existing = this.metrics.get(name);

    if (existing != null) {
      if (existing.type !== 'gauge') {
        throw new Error(`Metric ${name} already registered as ${existing.type}`);
      }

      return existing;
    }

    const created: GaugeMetric = {
      type: 'gauge',
      help,
      values: new Map(),
      labelsByKey: new Map(),
    };
    this.metrics.set(name, created);
    return created;
  }

  private getOrCreateSummary(name: string, help: string): SummaryMetric {
    const existing = this.metrics.get(name);

    if (existing != null) {
      if (existing.type !== 'summary') {
        throw new Error(`Metric ${name} already registered as ${existing.type}`);
      }

      return existing;
    }

    const created: SummaryMetric = {
      type: 'summary',
      help,
      values: new Map(),
      labelsByKey: new Map(),
    };
    this.metrics.set(name, created);
    return created;
  }

  private normalizeLabels(labels?: MetricLabels): Record<string, string> {
    if (labels == null) {
      return {};
    }

    return Object.entries(labels).reduce<Record<string, string>>(
      (accumulator, [key, value]) => {
        if (value == null) {
          return accumulator;
        }

        accumulator[this.sanitizeLabelName(key)] = String(value);
        return accumulator;
      },
      {},
    );
  }

  private serializeLabels(labels: Record<string, string>): string {
    return JSON.stringify(
      Object.entries(labels).sort(([left], [right]) => left.localeCompare(right)),
    );
  }

  private formatLabels(labels?: Record<string, string>): string {
    if (labels == null || Object.keys(labels).length === 0) {
      return '';
    }

    return `{${Object.entries(labels)
      .sort(([left], [right]) => left.localeCompare(right))
      .map(([key, value]) => `${key}="${value.replaceAll('"', '\\"')}"`)
      .join(',')}}`;
  }

  private sanitizeLabelName(labelName: string): string {
    return labelName.replace(/[^a-zA-Z0-9_]/g, '_');
  }
}
