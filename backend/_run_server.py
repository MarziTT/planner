import os, sys
os.chdir(r"F:\PixelPlanner\backend")
sys.path.insert(0, r"F:\PixelPlanner\backend")
os.environ["FLASK_ENV"] = "development"
from app import create_app
app = create_app(repair_tables=True)
app.run(host="0.0.0.0", port=5000, debug=False)
