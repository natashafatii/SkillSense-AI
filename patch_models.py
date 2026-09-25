import os

models_path = r'C:\Users\hp\Downloads\SkillSense_backend\interview_system\models.py'
with open(models_path, 'r', encoding='utf-8') as f:
    models_code = f.read()

models_old = '''def resume_upload_path(instance, filename):
    """Generate a unique upload path per candidate: resumes/<candidate_pk>/<uuid>.<ext>"""
    ext = filename.split(".")[-1].lower()
    return f"resumes/{instance.candidate_id}/{uuid.uuid4()}.{ext}"'''

models_new = '''def resume_upload_path(instance, filename):
    """Generate a unique upload path per candidate: resumes/<candidate_pk>/<filename>"""
    import re
    safe_name = re.sub(r'[^a-zA-Z0-9_.-]', '_', filename)
    return f"resumes/{instance.candidate_id}/{safe_name}"'''

if models_old in models_code:
    models_code = models_code.replace(models_old, models_new)
    with open(models_path, 'w', encoding='utf-8') as f:
        f.write(models_code)
    print('models.py patched successfully.')
else:
    print('models.py already patched or old code not found.')
