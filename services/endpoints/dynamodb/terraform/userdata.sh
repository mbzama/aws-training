#!/bin/bash
set -e
exec > /var/log/userdata.log 2>&1
echo "=== Starting UserData setup ==="

# ── System update and dependencies
yum update -y
yum install -y python3 python3-pip
pip3 install flask boto3 werkzeug

# ── Create app directory
mkdir -p /home/ec2-user/dynamodb-poc/templates

# ── Write Flask app
cat > /home/ec2-user/dynamodb-poc/app.py << 'PYEOF'
import os, time, uuid, boto3
from botocore.exceptions import ClientError
from flask import Flask, request, jsonify, render_template

app = Flask(__name__)

AWS_REGION = os.environ.get('AWS_REGION', 'us-east-1')
TABLE_NAME = os.environ.get('DYNAMODB_TABLE', 'dynamodb-vpc-endpoint-poc')

def get_table():
    dynamodb = boto3.resource('dynamodb', region_name=AWS_REGION)
    return dynamodb.Table(TABLE_NAME)

@app.route('/')
def index():
    return render_template('index.html', table=TABLE_NAME, region=AWS_REGION)

@app.route('/put', methods=['POST'])
def put_item():
    data = request.json or {}
    item_id = str(uuid.uuid4())
    item = {
        'id': item_id,
        'title': data.get('title', 'Untitled'),
        'value': data.get('value', ''),
        'created_at': time.strftime('%Y-%m-%d %H:%M:%S', time.gmtime())
    }
    start = time.time()
    try:
        get_table().put_item(Item=item)
        ms = round((time.time() - start) * 1000)
        return jsonify({'status': 'success', 'operation': 'PUT', 'id': item_id, 'ms': ms,
                        'message': f'Created: {item_id[:8]}...', 'item': item})
    except ClientError as e:
        ms = round((time.time() - start) * 1000)
        return jsonify({'status': 'error', 'operation': 'PUT', 'ms': ms, 'message': str(e)}), 500

@app.route('/scan')
def scan_items():
    start = time.time()
    try:
        res = get_table().scan()
        ms = round((time.time() - start) * 1000)
        items = res.get('Items', [])
        return jsonify({'status': 'success', 'operation': 'SCAN', 'ms': ms,
                        'count': len(items), 'items': items,
                        'message': f'Found {len(items)} item(s)'})
    except ClientError as e:
        ms = round((time.time() - start) * 1000)
        return jsonify({'status': 'error', 'operation': 'SCAN', 'ms': ms, 'message': str(e)}), 500

@app.route('/get/<item_id>')
def get_item(item_id):
    start = time.time()
    try:
        res = get_table().get_item(Key={'id': item_id})
        ms = round((time.time() - start) * 1000)
        item = res.get('Item')
        if item:
            return jsonify({'status': 'success', 'operation': 'GET', 'ms': ms,
                            'item': item, 'message': f'Retrieved: {item_id[:8]}...'})
        return jsonify({'status': 'error', 'operation': 'GET', 'ms': ms,
                        'message': 'Item not found'}), 404
    except ClientError as e:
        ms = round((time.time() - start) * 1000)
        return jsonify({'status': 'error', 'operation': 'GET', 'ms': ms, 'message': str(e)}), 500

@app.route('/delete/<item_id>', methods=['POST'])
def delete_item(item_id):
    start = time.time()
    try:
        get_table().delete_item(Key={'id': item_id})
        ms = round((time.time() - start) * 1000)
        return jsonify({'status': 'success', 'operation': 'DELETE', 'id': item_id, 'ms': ms,
                        'message': f'Deleted: {item_id[:8]}...'})
    except ClientError as e:
        ms = round((time.time() - start) * 1000)
        return jsonify({'status': 'error', 'operation': 'DELETE', 'ms': ms, 'message': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
PYEOF

# ── Write HTML template
cat > /home/ec2-user/dynamodb-poc/templates/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1.0"/>
<title>DynamoDB Gateway Endpoint POC</title>
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
  label{display:block;font-size:11px;color:#718096;margin-bottom:4px;text-transform:uppercase;letter-spacing:.5px}
  input[type=text],textarea{width:100%;padding:8px 10px;border:1px solid #cbd5e0;border-radius:6px;font-family:monospace;font-size:13px;margin-bottom:12px}
  textarea{resize:vertical;min-height:72px}
  .btn{padding:8px 18px;border-radius:6px;border:none;font-family:monospace;font-size:12px;cursor:pointer;font-weight:700}
  .btn:disabled{opacity:.5;cursor:not-allowed}
  .btn-blue{background:#3182ce;color:#fff}
  .btn-purple{background:#6b46c1;color:#fff}
  .btn-green{background:#38a169;color:#fff}
  .btn-red{background:#e53e3e;color:#fff}
  .btn-gray{background:#718096;color:#fff}
  .btn-sm{padding:4px 10px;font-size:11px}
  table{width:100%;border-collapse:collapse;font-size:12px}
  th{background:#f7fafc;padding:8px 12px;text-align:left;font-size:10px;text-transform:uppercase;letter-spacing:.5px;color:#718096;border-bottom:1px solid #e2e8f0}
  td{padding:9px 12px;border-bottom:1px solid #f0f0f0;vertical-align:top}
  tr:last-child td{border-bottom:none}
  .log-hdr th{background:#1a1a2e;color:#fff}
  .badge{display:inline-block;padding:2px 8px;border-radius:20px;font-size:10px;font-weight:700}
  .badge-success{background:#c6f6d5;color:#276749}
  .badge-error{background:#fed7d7;color:#c53030}
  .badge-put{background:#bee3f8;color:#2b6cb0}
  .badge-get{background:#faf5ff;color:#553c9a}
  .badge-scan{background:#fefcbf;color:#744210}
  .badge-delete{background:#fed7d7;color:#c53030}
  .ms-good{color:#38a169;font-weight:700}
  .ms-warn{color:#d69e2e;font-weight:700}
  .ms-bad{color:#e53e3e;font-weight:700}
  .empty{text-align:center;padding:28px;color:#a0aec0;font-size:12px}
  .note{background:#ebf8ff;border:1px solid #bee3f8;border-radius:6px;padding:10px 14px;font-size:11px;color:#2b6cb0;margin-top:10px}
  .row-btns{display:flex;gap:6px}
  .val-cell{max-width:220px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
  @media(max-width:600px){.stats{grid-template-columns:1fr 1fr}}
</style>
</head>
<body>
<div class="header">
  <h1>DynamoDB Gateway Endpoint POC</h1>
  <div class="meta">Table: <b>{{ table }}</b> &nbsp;|&nbsp; Region: <b>{{ region }}</b> &nbsp;|&nbsp; Flask server-side via VPC endpoint</div>
</div>
<div class="container">
  <div class="stats">
    <div class="stat"><div class="lbl">Avg PutItem</div><div class="val" id="avg-put">--</div></div>
    <div class="stat"><div class="lbl">Avg GetItem</div><div class="val" id="avg-get">--</div></div>
    <div class="stat"><div class="lbl">Total ops</div><div class="val" id="total-ops">0</div></div>
    <div class="stat"><div class="lbl">Errors</div><div class="val" id="total-errors" style="color:#e53e3e">0</div></div>
  </div>
  <div class="card">
    <div class="card-hdr">Create DynamoDB item</div>
    <div class="card-body">
      <label for="item-title">Title</label>
      <input type="text" id="item-title" placeholder="Item title" maxlength="100"/>
      <label for="item-value">Value</label>
      <textarea id="item-value" placeholder="Item value or notes"></textarea>
      <div style="display:flex;gap:10px;flex-wrap:wrap">
        <button class="btn btn-blue" onclick="putItem()">Create Item</button>
        <button class="btn btn-purple" onclick="scanItems()">Scan All Items</button>
        <button class="btn btn-gray" onclick="clearLog()">Clear Log</button>
      </div>
      <div class="note">All DynamoDB calls are made server-side by Flask on EC2 via the VPC Gateway Endpoint. Traffic never leaves the AWS private network.</div>
    </div>
  </div>
  <div class="card" id="items-card" style="display:none">
    <div class="card-hdr" id="items-hdr">Items in table</div>
    <div style="overflow-x:auto">
      <table><thead><tr><th>ID</th><th>Title</th><th>Value</th><th>Created At</th><th>Actions</th></tr></thead><tbody id="items-body"></tbody></table>
    </div>
  </div>
  <div class="card">
    <div class="card-hdr">Response log</div>
    <div id="log-empty" class="empty">No operations yet. Create an item or scan to start.</div>
    <div id="log-wrap" style="display:none;overflow-x:auto">
      <table><thead class="log-hdr"><tr><th>Time</th><th>Operation</th><th>ID</th><th>Response time</th><th>Result</th></tr></thead><tbody id="log-body"></tbody></table>
    </div>
  </div>
</div>
<script>
  var logs=[];
  function msc(ms){return ms<10?'ms-good':ms<100?'ms-warn':'ms-bad';}
  function addLog(e){e.time=new Date().toLocaleTimeString();logs.unshift(e);renderLog();updateStats();}
  function renderLog(){
    if(!logs.length){document.getElementById('log-empty').style.display='block';document.getElementById('log-wrap').style.display='none';return;}
    document.getElementById('log-empty').style.display='none';
    document.getElementById('log-wrap').style.display='block';
    document.getElementById('log-body').innerHTML=logs.map(function(l){
      var op=l.operation||'OP';
      var id=l.id?(l.id.substring(0,8)+'...'):(l.item&&l.item.id?l.item.id.substring(0,8)+'...':'--');
      return '<tr><td style="color:#718096">'+l.time+'</td><td><span class="badge badge-'+op.toLowerCase()+'">'+op+'</span></td><td style="color:#718096">'+id+'</td><td class="'+msc(l.ms)+'">'+(l.ms!=null?l.ms+' ms':'--')+'</td><td><span class="badge badge-'+l.status+'">'+l.message+'</span></td></tr>';
    }).join('');
  }
  function updateStats(){
    var pu=logs.filter(function(l){return l.operation==='PUT'&&l.status==='success';}).map(function(l){return l.ms;});
    var ge=logs.filter(function(l){return l.operation==='GET'&&l.status==='success';}).map(function(l){return l.ms;});
    function avg(a){return a.length?Math.round(a.reduce(function(x,y){return x+y;},0)/a.length)+' ms':'--';}
    document.getElementById('avg-put').textContent=avg(pu);
    document.getElementById('avg-get').textContent=avg(ge);
    document.getElementById('total-ops').textContent=logs.length;
    document.getElementById('total-errors').textContent=logs.filter(function(l){return l.status==='error';}).length;
  }
  async function putItem(){
    var title=document.getElementById('item-title').value.trim()||'Untitled';
    var value=document.getElementById('item-value').value.trim();
    try{
      var r=await fetch('/put',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({title:title,value:value})});
      addLog(await r.json());
    }catch(e){addLog({status:'error',operation:'PUT',ms:null,message:e.message});}
  }
  async function scanItems(){
    try{
      var r=await fetch('/scan');var d=await r.json();
      addLog({status:d.status,operation:'SCAN',ms:d.ms,message:d.message});
      if(d.items&&d.items.length>=0){
        document.getElementById('items-card').style.display='block';
        document.getElementById('items-hdr').textContent='Items in table ('+d.count+')';
        document.getElementById('items-body').innerHTML=d.items.length?d.items.map(function(o){
          return '<tr><td style="color:#718096">'+o.id.substring(0,8)+'...</td><td>'+esc(o.title||'')+'</td><td class="val-cell">'+esc(o.value||'')+'</td><td style="color:#718096">'+(o.created_at||'')+'</td><td><div class="row-btns"><button class="btn btn-green btn-sm" onclick="getItem(\''+o.id+'\')">Get</button><button class="btn btn-red btn-sm" onclick="delItem(\''+o.id+'\')">Delete</button></div></td></tr>';
        }).join(''):'<tr><td colspan="5" class="empty">Table is empty</td></tr>';
      }
    }catch(e){addLog({status:'error',operation:'SCAN',ms:null,message:e.message});}
  }
  async function getItem(id){
    try{var r=await fetch('/get/'+id);addLog(await r.json());}
    catch(e){addLog({status:'error',operation:'GET',ms:null,message:e.message});}
  }
  async function delItem(id){
    try{
      var r=await fetch('/delete/'+id,{method:'POST'});var d=await r.json();
      addLog(d);
      if(d.status==='success') scanItems();
    }catch(e){addLog({status:'error',operation:'DELETE',ms:null,message:e.message});}
  }
  function esc(s){var d=document.createElement('div');d.appendChild(document.createTextNode(s));return d.innerHTML;}
  function clearLog(){logs=[];renderLog();updateStats();}
</script>
</body>
</html>
HTMLEOF

# ── Write systemd service using printf (avoids variable expansion issues)
printf "[Unit]\nDescription=DynamoDB Gateway Endpoint POC Flask App\nAfter=network.target\n\n[Service]\nType=simple\nUser=ec2-user\nWorkingDirectory=/home/ec2-user/dynamodb-poc\nEnvironment=AWS_REGION=${aws_region}\nEnvironment=DYNAMODB_TABLE=${table_name}\nExecStart=/usr/bin/python3 /home/ec2-user/dynamodb-poc/app.py\nRestart=always\nRestartSec=5\n\n[Install]\nWantedBy=multi-user.target\n" > /etc/systemd/system/dynamodb-poc.service

# ── Fix ownership and start service
chown -R ec2-user:ec2-user /home/ec2-user/dynamodb-poc

systemctl daemon-reload
systemctl enable dynamodb-poc
systemctl start dynamodb-poc

echo "=== UserData setup complete ==="
