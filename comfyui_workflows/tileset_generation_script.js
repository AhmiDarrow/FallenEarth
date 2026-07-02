const http = require('http');

const API_HOST = "localhost";
const API_PORT = 8188;
const API_BASE = `http://${API_HOST}:${API_PORT}`;

const biomes = [
  "Ash Wastes",
  "Rust Canyons",
  "Neon Bogs",
  "Scorched Plains",
  "Ironwood Thicket",
  "Glass Dunes",
  "Corpse Fields",
  "Stormspire Highlands",
  "Toxin Marshes",
  "Dead City Outskirts",
];

function makeRequest(options, body = null) {
  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, statusText: res.statusMessage, body: JSON.parse(data) });
        } catch {
          resolve({ status: res.statusCode, statusText: res.statusMessage, body: data });
        }
      });
    });
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

async function generateBiome(name, index, seedBase, timeout = 180000) {
  const seed = seedBase * (index + 1);
  const workflowPath = "C:\\Users\\Administrator\\FallenEarth\\comfyui_workflows\\handdrawn_tileset_workflow.json";

  try {
    const submitOptions = {
      hostname: API_HOST,
      port: API_PORT,
      path: '/prompt',
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      }
    };

    const submitResp = await makeRequest(submitOptions, `json=${encodeURIComponent(workflowPath)}`);

    if (submitResp.status !== 200) {
      return { success: false, biome: name, error: submitResp.statusText };
    }

    const submitResult = submitResp.body;
    const promptId = submitResult.prompt_id;

    if (!promptId) {
      return { success: false, biome: name, error: 'No prompt_id in response' };
    }

    const maxAttempts = 200;
    for (let attempt = 0; attempt < maxAttempts; attempt++) {
      const statusResp = await makeRequest({
        hostname: API_HOST,
        port: API_PORT,
        path: `/job/${promptId}`,
        method: 'GET'
      });

      const statusResult = statusResp.body;
      const status = statusResult.status;

      if (status === 'completed') {
        const outputResp = await makeRequest({
          hostname: API_HOST,
          port: API_PORT,
          path: `/output/${promptId}`,
          method: 'GET'
        });

        if (outputResp.status === 200) {
          const outputData = outputResp.body;
          const images = outputData.images || [];
          return {
            success: true,
            biome: name,
            images: images,
            count: images.length,
            seed
          };
        }
        return { success: false, biome: name, error: `Failed to get output: ${outputResp.status}` };
      }

      if (status === 'error') {
        return { success: false, biome: name, error: statusResult.error || 'Unknown error' };
      }

      // queued, running, or unknown - wait and retry
      await new Promise(r => setTimeout(500, r));
    }

    return { success: false, biome: name, error: 'Timed out waiting for completion' };
  } catch (e) {
    console.error(`[FAIL] ${name}:`, e.message.slice(0, 80));
    return { success: false, biome: name, error: e.message.slice(0, 80) };
  }
}

async function main() {
  console.log("Starting tileset generation for all biomes...\n");

  const promises = biomes.map((name, i) =>
    generateBiome(name, i, 123456)
  );

  const results = await Promise.all(promises);

  console.log("\n" + "=".repeat(60));
  console.log("TILESET GENERATION COMPLETE");
  console.log("=".repeat(60));

  const successCount = results.filter(r => r.success).length;
  const failedCount = results.filter(r => !r.success).length;

  console.log(`\nResults: ${successCount} succeeded, ${failedCount} failed`);

  const output = [
    "Tileset Generation Results",
    "=".repeat(60),
    "",
    ...results.map(r =>
      `${r.success ? '✓' : '✗'} ${r.biome}: ${
        r.success ? `${r.count} images` : r.error.slice(0, 60)
      }`
    )
  ];

  const outputPath = "C:\\Users\\Administrator\\FallenEarth\\comfyui_workflows\\tileset_generation_results.txt";
  const fs = require('fs');
  fs.writeFileSync(outputPath, output.join('\n'));
  console.log(`\nFull results written to: ${outputPath}`);
}

main().catch(console.error);