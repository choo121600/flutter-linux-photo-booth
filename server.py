#!/usr/bin/env python3

from flask import Flask, request, jsonify
import cups

app = Flask(__name__)

def get_default_printer():
	conn = cups.Connection()
	printers = conn.getPrinters()
	return list(printers.keys())[0]

@app.route('/print', methods=['POST'])
def print_image():
	if 'filePath' not in request.form:
		return jsonify({"error": "No file path provided"}), 400

	filePath = request.form['filePath']

	try:
		printer_name = get_default_printer()
		image_path = filePath

		conn = cups.Connection()
		conn.printFile(printer_name, image_path, "Printing via CUPS Package", {})
	except Exception as e:
		return jsonify({"error": str(e)}), 500

	return jsonify({"message": "Successfully printed image"}), 200

if __name__ == '__main__':
	app.run()
