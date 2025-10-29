const PROGRESS_URL = "http://localhost:5000/status";
const SHUTDOWN_URL = "http://localhost:5000/shutdown";

let chart;

const customLinesPlugin = {
  id: 'customLinesPlugin',
  beforeDraw(chart) {
    const ctx = chart.ctx;
    const dataset = chart.data.datasets[0];
    const values = dataset.data;

    if (!values || values.length === 0) return;

    // 最大値と最小値
    const maxVal = Math.max(...values);
    const minVal = Math.min(...values);

    // 横軸スケール
    const xScale = chart.scales.x;
    const yScale = chart.scales.y;

    // 中央値位置（小さい方を取る）
    const sorted = [...values].sort((a, b) => a - b);
    const medianValue = sorted[Math.floor((sorted.length - 1) / 2)];
    const medianX = xScale.getPixelForValue(medianValue);

    // カットイン位置（最小値 × 0.6）
    const breakValue = chart.options.scales.x.min;
    console.log(chart.options.scales.x.max)
    const breakX = xScale.getPixelForValue(breakValue);

    ctx.save();

    // === break線 ===
    if (breakValue > 0){
      ctx.strokeStyle = '#222';
      ctx.lineWidth = 2;
      ctx.beginPath();
      const waveHeight = 5;
      const waveWidth = 5;
      let y = yScale.top;
      let dir = 1;
      ctx.moveTo(breakX, yScale.top);
      while (y <= yScale.bottom) {
        ctx.lineTo(breakX + dir * waveWidth, y);
        y += waveHeight;
        dir *= -1;
      }
      ctx.stroke();
    }

    // === 中央線 ===
    ctx.strokeStyle = '#888';
    ctx.setLineDash([4, 4]);
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.moveTo(medianX, yScale.top);
    ctx.lineTo(medianX, yScale.bottom);
    ctx.stroke();

    ctx.restore();
  },
  beforeUpdate(chart) {
    const values = chart.data.datasets[0].data;
    if (!values || values.length === 0) return;

    const sorted = [...values].sort((a, b) => a - b);
    const minVal = sorted[0];
    const maxVal = sorted[sorted.length - 1];
    const medianValue = sorted[Math.floor((sorted.length - 1) / 2)];

    const step = 10**digitCount(maxVal);

    const cutIn = Math.floor(Math.max(minVal - 5 * (medianValue - minVal), 0) /step)*step;
    const maxLimit = Math.ceil(Math.min(maxVal + (maxVal - minVal), 1.2 * maxVal) /step)*step;

    chart.options.scales.x.min = cutIn;
    chart.options.scales.x.max = maxLimit;
  },
};

function digitCount(n) {
  if (n === 0) return 1;
  return Math.floor(Math.log10(Math.abs(n)));
}

Chart.register(customLinesPlugin);

async function fetchStatus() {
  try {
    const res = await fetch(PROGRESS_URL);
    const data = await res.json();

    updateProgress(data);
    updateStatusText(data);
    updateStatInfo(data);
    updateLog(data.log);
    updateChart(data.workers, data.worker_times);
    updateShutdownButton(data.status);

  } catch (e) {
    document.getElementById("statusText").textContent = "⚠️ サーバーに接続できません";
    document.getElementById("shutdownBtn").style.display = "none";
  }
}

function updateProgress(data) {
  const bar = document.getElementById("progressBar");
  bar.max = data.total;
  bar.value = data.received;
}

function updateStatusText(data) {
  const formattedElapsedTime = formatDurationJP(data.elapsed);
  const text = `状態: ${data.status.toUpperCase()}｜${data.received}/${data.total} (${data.percent}%)｜経過: ${formattedElapsedTime}`;
  document.getElementById("statusText").textContent = text;
}

function updateStatInfo(data) {
// 平均処理時間を秒単位で取得して整形
const avgTimeSec = data.avg_time;
const formattedAvg = formatDurationJP(avgTimeSec);

// 残り時間 = (残タスク数 / worker数) * 平均時間（簡易）
const remainingTasks = data.total - data.received;
const workerCount = Object.keys(data.progress || {}).length || 1;
const remainingSec = avgTimeSec * remainingTasks / workerCount;
const formattedRemaining = formatDurationJP(remainingSec);

// 終了予測時刻
let formattedEndTime = '-';
if (data.log[data.log.length-1].timestamp && isFinite(remainingSec)) {
  const predictedEnd = new Date((data.log[data.log.length-1].timestamp + remainingSec) * 1000);
  formattedEndTime = formatEndTimeJP(predictedEnd);
}
  const html = `
  平均処理時間: <strong>${formattedAvg}</strong>　
  残り予測時間: <strong>${formattedRemaining}</strong>　
  終了予測時刻: <strong>${formattedEndTime}</strong>
`;
  document.getElementById("statInfo").innerHTML = html;
}

function updateLog(logs) {
  const container = document.getElementById("logList");
  container.innerHTML = logs.map(entry => {
    const t = new Date(entry.timestamp * 1000).toLocaleTimeString();
    return `<div>[${t}] Worker ${entry.worker} → Index ${entry.index}</div>`;
  }).join('');
}

function updateChart(workerData, workerTimes) {
  const canvas = document.getElementById('workerChart');
  const ctx = canvas.getContext('2d');
  const labels = Object.keys(workerData);
  const values = Object.values(workerData);
  const times = labels.map(wid => workerTimes[wid] || 0);

//   canvas.height = Math.max(labels.length * 20, 400);

  if (!chart) {
    chart = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: labels,
        datasets: [
          {
            label: '処理件数',
            data: values,
            backgroundColor: 'rgba(54, 162, 235, 0.6)',
            xAxisID: 'x'
          }
          // },
          // {
          //   label: '平均処理時間 (s)',
          //   data: times,
          //   backgroundColor: 'rgba(255, 99, 132, 0.6)',
          //   xAxisID: 'x2'
          // }
        ]
      },
      options: {
        indexAxis: 'y',
        responsive: true,
        maintainAspectRatio: false,
        scales: {
          x: {
            position: 'bottom',
            beginAtZero: false,
            title: { display: true, text: '処理件数' }
          },
          // x2: {
          //   position: 'top',
          //   beginAtZero: true,
          //   title: { display: true, text: '平均処理時間 (s)' },
          //   grid: { drawOnChartArea: false }
          // },
          y: {
            title: { display: true, text: 'ワーカーID' }
          }
        },
        plugins:{
          customLinesPlugin: true
        },
      }
    });
  } else {
    chart.data.labels = labels;
    chart.data.datasets[0].data = values;
    // chart.data.datasets[1].data = times;
    chart.update();
  }
}

function updateShutdownButton(status) {
  const btn = document.getElementById("shutdownBtn");
  btn.style.display = (status === "done") ? "inline-block" : "none";
}

async function shutdownServer() {
  if (!confirm("⚠️ 本当にサーバーを終了しますか？")) return;

  try {
    const res = await fetch(SHUTDOWN_URL, { method: "POST" });
    const data = await res.json();
    alert(data.message);
  } catch (e) {
    alert("シャットダウンに失敗しました。");
  }
}

function formatTime(totalSeconds) {
  if (totalSeconds === null || isNaN(totalSeconds)) {
    return 'N/A'; // または他の適切な表示
  }

  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = Math.floor(totalSeconds % 60);
  const milliseconds = Math.floor((totalSeconds - Math.floor(totalSeconds)) * 100); // 小数点以下1桁なので100を掛ける

  // 各部分を2桁表示にフォーマット（秒は小数点以下1桁）
  const formattedHours = String(hours).padStart(2, '0');
  const formattedMinutes = String(minutes).padStart(2, '0');
  const formattedSeconds = String(seconds).padStart(2, '0');
  const formattedMilliseconds = String(milliseconds).padStart(1, '0').slice(0, 1); // 常に1桁になるように調整

  return `${formattedHours}:${formattedMinutes}:${formattedSeconds}.${formattedMilliseconds}`;
}

function formatDurationJP(totalSeconds) {
  if (!isFinite(totalSeconds)) return '-';
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = (totalSeconds % 60).toFixed(2);
  if (hours > 0) {
    return `${hours}時間${String(minutes).padStart(2, '0')}分${seconds.padStart(5, '0')}秒`;
  } else if (minutes > 0) {
    return `${minutes}分${seconds.padStart(5, '0')}秒`;
  } else {
    return `${seconds.padStart(5, '0')}秒`;
  }
}

function formatEndTimeJP(date) {
  const mm = String(date.getMonth() + 1).padStart(2, '0');
  const dd = String(date.getDate()).padStart(2, '0');
  const hh = String(date.getHours()).padStart(2, '0');
  const min = String(date.getMinutes()).padStart(2, '0');
  return `${mm}月${dd}日${hh}時${min}分`;
}

setInterval(fetchStatus, 1000);
fetchStatus();