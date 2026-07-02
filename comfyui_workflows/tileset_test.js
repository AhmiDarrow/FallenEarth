#!/usr/bin/env node

const http = require('http');

const WORKFLOW_PATH = 'C:\\Users\\Administrator\\FallenEarth\\comfyui_workflows\\handdrawn_tileset_workflow.json';

function testSubmission() {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'localhost',
      port: 8188,
      path: '/prompt',
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': Buffer.byteLength(WORKFLOW_PATH)
      }
    };

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        console.log(`Status: ${res.statusCode}`);
        console.log(`Headers:`, JSON.stringify(res.headers, null, 2));
        console.log(`Body length: ${data.length}`);
        if (data.length > 0) {
          try {
            const result = JSON.parse(data);
            console.log(`Parsed result:`, JSON.stringify(result, null, 2));
          } catch {
            console.log(`Raw body (first 500 chars):`, data.substring(0, 500));
          }
        }
        resolve();
      });
    });

    req.on('error', (err) => {
      console.error('Request error:', err.message);
      reject(err);
    });

    req.write(WORKFLOW_PATH);
    req.end();
  });
}

testSubmission().catch(console.error);