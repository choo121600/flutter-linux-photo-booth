#!/usr/bin/env python3

from flask import Flask, request, jsonify
import cups
import base64
import tempfile
import os

app = Flask(__name__)

def get_default_printer():
	conn = cups.Connection()
	printers = conn.getPrinters()
	if not printers:
		raise Exception("No printers found")
	return list(printers.keys())[0]

@app.route('/print', methods=['POST'])
def print_image():
	try:
		# JSON 데이터로 base64 이미지를 받는 경우 (새로운 방식)
		if request.is_json:
			data = request.get_json()
			if 'imageData' not in data:
				return jsonify({"error": "No image data provided"}), 400
			
			# base64 이미지 데이터 디코딩
			image_data = base64.b64decode(data['imageData'])
			filename = data.get('filename', 'photo_booth_print.png')
			
			# 임시 파일 생성 (메모리에서 바로 프린트하기 위해)
			with tempfile.NamedTemporaryFile(delete=False, suffix='.png') as temp_file:
				temp_file.write(image_data)
				temp_file_path = temp_file.name
			
			try:
				printer_name = get_default_printer()
				conn = cups.Connection()
				
				# 이미지 프린트 (적절한 옵션 설정)
				options = {
					'media': 'A4',  # 용지 크기
					'fit-to-page': 'True',  # 페이지에 맞춤
					'orientation-requested': '3'  # Portrait
				}
				
				conn.printFile(printer_name, temp_file_path, "Photo Booth Print", options)
				
				# 임시 파일 삭제
				os.unlink(temp_file_path)
				
				return jsonify({"message": "Successfully printed image"}), 200
				
			except Exception as e:
				# 에러 발생 시 임시 파일 삭제
				if os.path.exists(temp_file_path):
					os.unlink(temp_file_path)
				raise e
		
		# 기존 파일 경로 방식 (호환성을 위해 유지)
		elif 'filePath' in request.form:
			filePath = request.form['filePath']
			
			if not os.path.exists(filePath):
				return jsonify({"error": "File not found"}), 404
			
			printer_name = get_default_printer()
			conn = cups.Connection()
			conn.printFile(printer_name, filePath, "Photo Booth Print", {})
			
			return jsonify({"message": "Successfully printed image"}), 200
		
		else:
			return jsonify({"error": "No image data or file path provided"}), 400
			
	except Exception as e:
		print(f"Print error: {str(e)}")
		return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
	app.run()
