#!/bin/bash
set -e
exec > /var/log/userdata.log 2>&1
echo "=== Starting UserData setup ==="

# ── System update and dependencies
yum update -y
yum install -y python3 python3-pip
pip3 install flask boto3 werkzeug

# ── Create app directory
mkdir -p /home/ec2-user/s3-poc/templates

# ── Write Flask app
cat > /home/ec2-user/s3-poc/app.py << 'PYEOF'
import os, time, boto3, io
from botocore.exceptions import ClientError
from flask import Flask, request, jsonify, render_template, send_file

app = Flask(__name__)

AWS_REGION  = os.environ.get('AWS_REGION', 'us-east-1')
BUCKET_NAME = os.environ.get('S3_BUCKET', 'default-bucket')

def get_s3():
    return boto3.client('s3', region_name=AWS_REGION)

@app.route('/')
def index():
    return render_template('index.html', bucket=BUCKET_NAME, region=AWS_REGION)

@app.route('/upload', methods=['POST'])
def upload():
    if 'file' not in request.files:
        return jsonify({'error': 'No file'}), 400
    file  = request.files['file']
    key   = f'poc-uploads/{int(time.time())}-{file.filename}'
    start = time.time()
    try:
        data = file.read()
        get_s3().put_object(Bucket=BUCKET_NAME, Key=key, Body=data, ContentType=file.content_type)
        ms = round((time.time() - start) * 1000)
        return jsonify({'status':'success','operation':'UPLOAD','file':file.filename,'key':key,'size':len(data),'ms':ms,'message':f'Uploaded to s3://{BUCKET_NAME}/{key}'})
    except ClientError as e:
        ms = round((time.time() - start) * 1000)
        return jsonify({'status':'error','operation':'UPLOAD','file':file.filename,'size':0,'ms':ms,'message':str(e)}), 500

@app.route('/list')
def list_objects():
    start = time.time()
    try:
        res     = get_s3().list_objects_v2(Bucket=BUCKET_NAME, Prefix='poc-uploads/')
        ms      = round((time.time() - start) * 1000)
        objects = [{'key':o['Key'],'filename':o['Key'].split('/')[-1],'size':o['Size'],'last_modified':o['LastModified'].strftime('%Y-%m-%d %H:%M:%S')} for o in res.get('Contents',[])]
        return jsonify({'status':'success','operation':'LIST','ms':ms,'count':len(objects),'objects':objects,'message':f'Found {len(objects)} object(s)'})
    except ClientError as e:
        ms = round((time.time() - start) * 1000)
        return jsonify({'status':'error','operation':'LIST','ms':ms,'message':str(e)}), 500

@app.route('/download-time/<path:key>')
def download_time(key):
    start = time.time()
    try:
        res  = get_s3().get_object(Bucket=BUCKET_NAME, Key=key)
        data = res['Body'].read()
        ms   = round((time.time() - start) * 1000)
        return jsonify({'status':'success','operation':'DOWNLOAD','file':key.split('/')[-1],'size':len(data),'ms':ms,'message':'Downloaded successfully','key':key})
    except ClientError as e:
        ms = round((time.time() - start) * 1000)
        return jsonify({'status':'error','operation':'DOWNLOAD','ms':ms,'message':str(e)}), 500

@app.route('/download/<path:key>')
def download(key):
    try:
        res  = get_s3().get_object(Bucket=BUCKET_NAME, Key=key)
        data = res['Body'].read()
        return send_file(io.BytesIO(data), download_name=key.split('/')[-1], as_attachment=True)
    except ClientError as e:
        return jsonify({'status':'error','message':str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
PYEOF

# ── Write HTML template
cat > /home/ec2-user/s3-poc/templates/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1.0"/>
<title>S3 Gateway Endpoint POC</title>
<style>
  *{margin:0;padding:0;box-sizing:border-box}
  body{font-family:monospace;background:#f5f5f5;color:#1a1a1a}
  .header{background:#1a1a2e;color:#fff;padding:18px 32px;display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:8px}
  .header h1{font-size:17px}
  .meta{font-size:11px;color:#a0aec0}
  .container{max-width:960px;margin:0 auto;padding:24px 16px}
  .stats{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin-bottom:20px}
  .stat{background:#fff;border-radius:8px;padding:14px;border:1px solid #e2e8f0}
  .stat .lbl{font-size:10px;color:#718096;text-transform:uppercase;letter-spacing:.5px}
  .stat .val{font-size:22px;font-weight:700;margin-top:4px}
  .card{background:#fff;border-radius:8px;border:1px solid #e2e8f0;margin-bottom:18px}
  .card-hdr{padding:12px 18px;border-bottom:1px solid #e2e8f0;font-size:13px;font-weight:700;color:#2d3748}
  .card-body{padding:18px}
  .dropzone{border:2px dashed #cbd5e0;border-radius:8px;padding:22px;text-align:center;cursor:pointer;transition:border-color .2s;margin-bottom:12px}
  .dropzone:hover{border-color:#4299e1}
  .hint{font-size:12px;color:#718096;margin-top:4px}
  .btn{padding:8px 18px;border-radius:6px;border:none;font-family:monospace;font-size:12px;cursor:pointer;font-weight:700}
  .btn:disabled{opacity:.5;cursor:not-allowed}
  .btn-blue{background:#3182ce;color:#fff}
  .btn-purple{background:#6b46c1;color:#fff}
  .btn-green{background:#38a169;color:#fff}
  .btn-gray{background:#718096;color:#fff}
  .btn-sm{padding:4px 10px;font-size:11px}
  table{width:100%;border-collapse:collapse;font-size:12px}
  th{background:#f7fafc;padding:8px 12px;text-align:left;font-size:10px;text-transform:uppercase;letter-spacing:.5px;color:#718096;border-bottom:1px solid #e2e8f0}
  td{padding:9px 12px;border-bottom:1px solid #f0f0f0}
  tr:last-child td{border-bottom:none}
  .log-hdr th{background:#1a1a2e;color:#fff}
  .badge{display:inline-block;padding:2px 8px;border-radius:20px;font-size:10px;font-weight:700}
  .badge-success{background:#c6f6d5;color:#276749}
  .badge-error{background:#fed7d7;color:#c53030}
  .badge-upload{background:#bee3f8;color:#2b6cb0}
  .badge-download{background:#faf5ff;color:#553c9a}
  .badge-list{background:#fefcbf;color:#744210}
  .ms-good{color:#38a169;font-weight:700}
  .ms-warn{color:#d69e2e;font-weight:700}
  .ms-bad{color:#e53e3e;font-weight:700}
  .empty{text-align:center;padding:28px;color:#a0aec0;font-size:12px}
  .note{background:#ebf8ff;border:1px solid #bee3f8;border-radius:6px;padding:10px 14px;font-size:11px;color:#2b6cb0;margin-top:10px}
  @media(max-width:600px){.stats{grid-template-columns:1fr 1fr}}
</style>
</head>
<body>
<div class="header">
  <h1>S3 Gateway Endpoint POC</h1>
  <div class="meta">Bucket: <b>{{ bucket }}</b> &nbsp;|&nbsp; Region: <b>{{ region }}</b> &nbsp;|&nbsp; Flask server-side via VPC endpoint</div>
</div>
<div class="container">
  <div class="stats">
    <div class="stat"><div class="lbl">Avg upload</div><div class="val" id="avg-upload">--</div></div>
    <div class="stat"><div class="lbl">Avg download</div><div class="val" id="avg-download">--</div></div>
    <div class="stat"><div class="lbl">Total ops</div><div class="val" id="total-ops">0</div></div>
    <div class="stat"><div class="lbl">Errors</div><div class="val" id="total-errors" style="color:#e53e3e">0</div></div>
  </div>
  <div class="card">
    <div class="card-hdr">Upload image to S3</div>
    <div class="card-body">
      <div class="dropzone" onclick="document.getElementById('fileInput').click()">
        <input type="file" id="fileInput" accept="image/*" style="display:none" onchange="handleFile(this)"/>
        <div id="drop-hint">Click to select an image file</div>
        <div class="hint">JPG, PNG, GIF, WEBP</div>
      </div>
      <div style="display:flex;gap:10px;flex-wrap:wrap">
        <button class="btn btn-blue" id="upload-btn" onclick="uploadFile()" disabled>Upload to S3</button>
        <button class="btn btn-purple" onclick="listObjects()">List objects</button>
        <button class="btn btn-gray" onclick="clearLog()">Clear log</button>
      </div>
      <div class="note">All S3 calls are made server-side by Flask on EC2 via the VPC Gateway Endpoint. Traffic never leaves the AWS private network.</div>
    </div>
  </div>
  <div class="card" id="file-card" style="display:none">
    <div class="card-hdr" id="file-hdr">Objects in bucket</div>
    <div style="overflow-x:auto">
      <table><thead><tr><th>Filename</th><th>Size</th><th>Last modified</th><th>Action</th></tr></thead><tbody id="file-body"></tbody></table>
    </div>
  </div>
  <div class="card">
    <div class="card-hdr">Response log</div>
    <div id="log-empty" class="empty">No operations yet. Upload or list to start.</div>
    <div id="log-wrap" style="display:none;overflow-x:auto">
      <table><thead class="log-hdr"><tr><th>Time</th><th>Operation</th><th>File</th><th>Size</th><th>Response time</th><th>Result</th></tr></thead><tbody id="log-body"></tbody></table>
    </div>
  </div>
</div>
<script>
  var logs=[],sel=null;
  function fmt(b){return !b?'--':b<1024?b+' B':b<1048576?(b/1024).toFixed(1)+' KB':(b/1048576).toFixed(2)+' MB';}
  function msc(ms){return ms<500?'ms-good':ms<2000?'ms-warn':'ms-bad';}
  function handleFile(i){sel=i.files[0];if(sel){document.getElementById('drop-hint').textContent=sel.name+' ('+fmt(sel.size)+')';document.getElementById('upload-btn').disabled=false;}}
  function addLog(e){e.time=new Date().toLocaleTimeString();logs.unshift(e);renderLog();updateStats();}
  function renderLog(){
    if(!logs.length){document.getElementById('log-empty').style.display='block';document.getElementById('log-wrap').style.display='none';return;}
    document.getElementById('log-empty').style.display='none';
    document.getElementById('log-wrap').style.display='block';
    document.getElementById('log-body').innerHTML=logs.map(function(l){
      return '<tr><td style="color:#718096">'+l.time+'</td><td><span class="badge badge-'+l.operation.toLowerCase()+'">'+l.operation+'</span></td><td>'+(l.file||'--')+'</td><td>'+fmt(l.size)+'</td><td class="'+msc(l.ms)+'">'+(l.ms!=null?l.ms+' ms':'--')+'</td><td><span class="badge badge-'+l.status+'">'+l.message+'</span></td></tr>';
    }).join('');
  }
  function updateStats(){
    var up=logs.filter(function(l){return l.operation==='UPLOAD'&&l.status==='success';}).map(function(l){return l.ms;});
    var dn=logs.filter(function(l){return l.operation==='DOWNLOAD'&&l.status==='success';}).map(function(l){return l.ms;});
    function avg(a){return a.length?Math.round(a.reduce(function(x,y){return x+y;},0)/a.length)+' ms':'--';}
    document.getElementById('avg-upload').textContent=avg(up);
    document.getElementById('avg-download').textContent=avg(dn);
    document.getElementById('total-ops').textContent=logs.length;
    document.getElementById('total-errors').textContent=logs.filter(function(l){return l.status==='error';}).length;
  }
  async function uploadFile(){
    if(!sel)return;
    var btn=document.getElementById('upload-btn');btn.disabled=true;btn.textContent='Uploading...';
    var fd=new FormData();fd.append('file',sel);
    try{var r=await fetch('/upload',{method:'POST',body:fd});addLog(await r.json());}
    catch(e){addLog({status:'error',operation:'UPLOAD',file:sel.name,ms:null,message:e.message});}
    finally{btn.disabled=false;btn.textContent='Upload to S3';}
  }
  async function listObjects(){
    try{
      var r=await fetch('/list');var d=await r.json();
      addLog({status:d.status,operation:'LIST',file:'poc-uploads/',size:null,ms:d.ms,message:d.message});
      if(d.objects&&d.objects.length){
        document.getElementById('file-card').style.display='block';
        document.getElementById('file-hdr').textContent='Objects in bucket ('+d.count+')';
        document.getElementById('file-body').innerHTML=d.objects.map(function(o){
          return '<tr><td>'+o.filename+'</td><td>'+fmt(o.size)+'</td><td style="color:#718096">'+o.last_modified+'</td><td><button class="btn btn-green btn-sm" onclick="dlFile(\''+o.key+'\',\''+o.filename+'\')">Download</button></td></tr>';
        }).join('');
      }
    }catch(e){addLog({status:'error',operation:'LIST',file:'--',ms:null,message:e.message});}
  }
  async function dlFile(key,name){
    try{
      var r=await fetch('/download-time/'+key);var d=await r.json();addLog(d);
      var a=document.createElement('a');a.href='/download/'+key;a.download=name;a.click();
    }catch(e){addLog({status:'error',operation:'DOWNLOAD',file:name,ms:null,message:e.message});}
  }
  function clearLog(){logs=[];renderLog();updateStats();}
</script>
</body>
</html>
HTMLEOF

# ── Write systemd service using printf (avoids variable expansion issues)
printf "[Unit]\nDescription=S3 Gateway Endpoint POC Flask App\nAfter=network.target\n\n[Service]\nType=simple\nUser=ec2-user\nWorkingDirectory=/home/ec2-user/s3-poc\nEnvironment=AWS_REGION=${aws_region}\nEnvironment=S3_BUCKET=${bucket_name}\nExecStart=/usr/bin/python3 /home/ec2-user/s3-poc/app.py\nRestart=always\nRestartSec=5\n\n[Install]\nWantedBy=multi-user.target\n" > /etc/systemd/system/s3-poc.service

# ── Fix ownership and start service
chown -R ec2-user:ec2-user /home/ec2-user/s3-poc

systemctl daemon-reload
systemctl enable s3-poc
systemctl start s3-poc

echo "=== UserData setup complete ==="
