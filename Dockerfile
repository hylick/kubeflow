FROM gcr.io/kubeflow-images-staging/tensorflow-1.6.0-notebook-cpu
COPY gen_data.py /home/jovyan/gen_data.py
COPY model.py /home/jovyan/model.py
COPY run.py /home/jovyan/run.py
