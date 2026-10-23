import { BarChart, LineChart } from 'echarts/charts';
import { GridComponent, LegendComponent, TooltipComponent } from 'echarts/components';
import * as echarts from 'echarts/core';
import { CanvasRenderer } from 'echarts/renderers';
import type { EChartsCoreOption } from 'echarts/core';

// Only the pieces the reports use: line and bar charts on a canvas.
echarts.use([
  LineChart,
  BarChart,
  GridComponent,
  LegendComponent,
  TooltipComponent,
  CanvasRenderer,
]);

export { echarts };

/** The theme tokens charts need, read from the CSS variables of the current theme. */
export interface ChartColors {
  fg: string;
  muted: string;
  border: string;
  surface: string;
  primary: string;
  income: string;
  expenses: string;
}

export function chartColors(): ChartColors {
  const style = getComputedStyle(document.documentElement);
  const read = (name: string) => style.getPropertyValue(name).trim();
  return {
    fg: read('--c-fg'),
    muted: read('--c-fg-muted'),
    border: read('--c-border'),
    surface: read('--c-surface'),
    primary: read('--c-primary'),
    income: read('--c-chart-in'),
    expenses: read('--c-chart-out'),
  };
}

/** Recessive axes and grid, tooltip on the theme surface (dataviz anatomy). */
export function baseOptions(colors: ChartColors): EChartsCoreOption {
  return {
    animationDuration: 300,
    textStyle: { fontFamily: 'Inter Variable, system-ui, sans-serif', color: colors.muted },
    grid: { left: 8, right: 16, top: 36, bottom: 8, containLabel: true },
    tooltip: {
      trigger: 'axis',
      backgroundColor: colors.surface,
      borderColor: colors.border,
      textStyle: { color: colors.fg, fontSize: 12 },
      axisPointer: { type: 'line', lineStyle: { color: colors.border } },
    },
    legend: {
      top: 0,
      left: 0,
      icon: 'roundRect',
      itemWidth: 10,
      itemHeight: 10,
      textStyle: { color: colors.fg, fontSize: 12 },
    },
  };
}

export function axisStyle(colors: ChartColors) {
  return {
    axisLine: { lineStyle: { color: colors.border } },
    axisTick: { show: false },
    axisLabel: { color: colors.muted, fontSize: 11 },
    splitLine: { lineStyle: { color: colors.border, opacity: 0.6 } },
  };
}
