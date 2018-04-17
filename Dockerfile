FROM gcr.io/kubeflow-images-staging/tensorflow-1.6.0-notebook-cpu
COPY gen_data.py /workdir/gen_data.py
COPY model.py /workdir/model.py
COPY run.py /workdir/run.py
RUN chmod +x /workdir/run.py
RUN ls -lah /workdir
