#!/usr/bin/env node

const http = require('http');

const API_BASE = 'http://localhost:8188';
const WORKFLOW_PATH = 'C:\\Users\\Administrator\\FallenEarth\\comfyui_workflows\\handdrawn_tileset_workflow.json';

function submitWorkflow(workflowPath) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'localhost',
      port: 8188,
      path: '/prompt',
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': Buffer.byteLength(workflowPath)
      }
    };

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const result = JSON.parse(data);
          resolve({ status: res.statusCode, prompt_id: result.prompt_id, raw: result });
        } catch (e) {
          resolve({ status: res.statusCode, raw: data });
        }
      });
    });

    req.on('error', reject);
    req.write(workflowPath);
    req.end();
  });
}

function waitForCompletion(promptId, maxAttempts = 200) {
  return new Promise((resolve) => {
    const interval = setInterval(() => {
      const options = { hostname: 'localhost', port: 8188, path: `/job/${promptId}`, method: 'GET' };
      const req = http.request(options, (res) => {
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => {
          clearInterval(interval);
          try {
            const result = JSON.parse(data);
            resolve({ status: result.status, result });
          } catch {
            resolve({ status: res.statusCode, raw: data });
          }
        });
      });
      req.on('error', () => clearInterval(interval));
    }, 500);
  });
}

async function generateBiome(name, index, seed) {
  console.log(`[${new Date().toLocaleTimeString()}] Starting: ${name} (seed: ${seed})`);

  try {
    const submitResult = await submitWorkflow(WORKFLOW_PATH);

    if (submitResult.status !== 200) {
      console.log(`[${new Date().toLocaleTimeString()}] [FAIL] ${name}: HTTP ${submitResult.status}`);
      return null;
    }

    const promptId = submitResult.prompt_id;
    if (!promptId) {
      console.log(`[${new Date().toLocaleTimeString()}] [FAIL] ${name}: No prompt_id received`);
      return null;
    }

    console.log(`[${new Date().toLocaleTimeString()}] [OK] ${name}: Submitted, prompt_id: ${promptId}`);

    const completionResult = await waitForCompletion(promptId);
    const finalStatus = completionResult.status;

    if (finalStatus === 'completed') {
      const outputResult = await fetchOutput(promptId);
      if (outputResult) {
        console.log(`[${new Date().toLocaleTimeString()}] [OK] ${name}: Completed - ${outputResult.images.length} images`);
        return {
          success: true,
          biome: name,
          seed,
          images: outputResult.images,
          count: outputResult.images.length
        };
      }
    }

    console.log(`[${new Date().toLocaleTimeString()}] [WARN] ${name}: Final status: ${finalStatus}`);
    return {
      success: false,
      biome: name,
      seed,
      status: finalStatus
    };
  } catch (error) {
    console.log(`[${new Date().toLocaleTimeString()}] [ERROR] ${name}: ${error.message}`);
    return { success: false, biome: name, seed, error: error.message };
  }
}

async function fetchOutput(promptId) {
  return new Promise((resolve) => {
    const options = { hostname: 'localhost', port: 8188, path: `/output/${promptId}`, method: 'GET' };
    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        if (res.statusCode === 200) {
          try {
            const result = JSON.parse(data);
            resolve({ images: result.images || [], count: result.images?.length || 0 });
          } catch {
            resolve(null);
          }
        } else {
          resolve(null);
        }
      });
    });
    req.on('error', () => resolve(null));
  });
}

async function main() {
  const seeds = [123456, 654321, 987654];
  const biomes = [
    { name: 'Ash Wastes', index: 0 },
    { name: 'Rust Canyons', index: 1 },
    { name: 'Neon Bogs', index: 2 },
    { name: 'Scorched Plains', index: 3 },
    { name: 'Ironwood Thicket', index: 4 },
    { name: 'Glass Dunes', index: 5 },
    { name: 'Corpse Fields', index: 6 },
    { name: 'Stormspire Highlands', index: 7 },
    { name: 'Toxin Marshes', index: 8 },
    { name: 'Dead City Outskirts', index: 9 },
  ];

  const results = [];
  for (const biome of biomes) {
    for (const seed of seeds) {
      const result = await generateBiome(biome.name, biome.index, seed);
      results.push(result);
    }
  }

  const summary = results.filter(r => r.success);
  console.log(`\n\n=== FINAL SUMMARY ===`);
  console.log(`Total attempts: ${results.length}`);
  console.log(`Successful: ${summary.length}`);
  console.log(`Failed: ${results.length - summary.length}`);

  // Write to file
  const outputPath = 'C:\\Users\\Administrator\\FallenEarth\\comfyui_workflows\\tileset_generation_results.txt';
  const lines = [
    'Tileset Generation Results',
    '='.repeat(60),
    '',
    `Total attempts: ${results.length}`,
    `Successful: ${summary.length}`,
    `Failed: ${results.length - summary.length}`,
    ''
  ];

  for (const r of results) {
    lines.push(`${r.success ? '✓' : '✗'} ${r.biome} (seed: ${r.seed}) - ${r.status || 'N/A'}`);
  }

  const fs = require('fs');
  fs.writeFileSync(outputPath, lines.join('\n'));
  console.log(`\nResults written to: ${outputPath}`);
}

main().catch(console.error);