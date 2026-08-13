<script>
import { Line } from 'vue-chartjs';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Tooltip,
  Legend,
  Filler,
} from 'chart.js';

ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Tooltip,
  Legend,
  Filler
);

export default {
  name: 'LineChart',
  components: { Line },
  props: {
    data: { type: Object, required: true },
    options: { type: Object, default: () => ({}) },
  },
};
</script>

<template>
  <Line :data="data" :options="options" />
</template>
