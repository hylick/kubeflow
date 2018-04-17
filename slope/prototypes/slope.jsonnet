// @apiVersion 0.1
// @name io.ksonnet.pkg.slope
// @description A TensorFlow ML MVP code distributed job
// @shortDescription Run MVP TensorFlow ML code job.
// @param name string Name for the job.
// @optionalParam namespace string null Namespace to use for the components. It is automatically inherited from the environment if not set.
// @optionalParam batch_size number 3 The batch size
// @optionalParam num_gpus number 0 The number of GPUs to attach to workers.
// @optionalParam image string gcr.io/hylick-external/tf-job-slope:latest The docker image to use for the job.
// @optionalParam image_gpu string gcr.io/hylick-external/tf-job-slope:latest The docker image to use when using GPUs.
// @optionalParam num_ps number 1 The number of ps to use
// @optionalParam num_workers number 1 The number of workers to use

// We need at least 1 parameter server.

local k = import "k.libsonnet";
local deployment = k.extensions.v1beta1.deployment;
local container = deployment.mixin.spec.template.spec.containersType;
local podTemplate = k.extensions.v1beta1.podTemplate;

// updatedParams uses the environment namespace if
// the namespace parameter is not explicitly set
local updatedParams = params {
  namespace: if params.namespace == "null" then env.namespace else params.namespace,
};

local tfJob = import "kubeflow/tf-job/tf-job.libsonnet";

local name = import "param://name";
local namespace = updatedParams.namespace;

local numGpus = import "param://num_gpus";
local batchSize = import "param://batch_size";
local model = import "param://model";

local mode = "train";
local num_inputs = "2";
local num_outputs = "2";
local num_neurons = "2";
local batch_size = "3";
local learning_rate = "0.01";
local num_layers = "1";
local num_epochs = "5000";
local checkpoint_dir = "./foo";

local args = [
               "python",
               "run.py",
               "--mode=" + mode,
               "--num_inputs=" + num_inputs,
               "--num_outputs=" + num_outputs,
               "--num_neurons=" + num_neurons,
               "--batch_size=" + batch_size,
               "--learning_rate=" + learning_rate,
               "--num_layers=" + num_layers,
               "--num_epochs=" + num_epochs,
               "--checkpoint_dir=" + checkpoint_dir,
             ] +
             if numGpus == 0 then
               // We need to set num_gpus=1 even if not using GPUs because otherwise the devie list
               // is empty because of this code
               // https://github.com/tensorflow/benchmarks/blob/master/scripts/tf_cnn_benchmarks/benchmark_cnn.py#L775
               // We won't actually use GPUs because based on other flags no ops will be assigned to GPus.
               [
                 "--num_gpus=1",
                 "--local_parameter_device=cpu",
                 "--device=cpu",
                 "--data_format=NHWC",
               ]
             else
               [
                 "--num_gpus=" + numGpus,
               ]
;

local image = import "param://image";
local imageGpu = import "param://image_gpu";
local numPs = import "param://num_ps";
local numWorkers = import "param://num_workers";
local numGpus = import "param://num_gpus";

local workerSpec = if numGpus > 0 then
  tfJob.parts.tfJobReplica("WORKER", numWorkers, args, imageGpu, numGpus)
else
  tfJob.parts.tfJobReplica("WORKER", numWorkers, args, image);

local replicas = std.map(function(s)
                           s {
                             template+: {
                               spec+: {
                                 containers: [
                                   s.template.spec.containers[0] {
                                     workingDir: "/home/jovyan",
                                   },
                                 ],
                               },
                             },
                           },
                         std.prune([workerSpec, tfJob.parts.tfJobReplica("PS", numPs, args, image)]));

local job =
  if numWorkers < 1 then
    error "num_workers must be >= 1"
  else
    if numPs < 1 then
      error "num_ps must be >= 1"
    else
      tfJob.parts.tfJob(name, namespace, replicas, null) + {
        spec+: {
          tfImage: image,
          terminationPolicy: { chief: { replicaName: "WORKER", replicaIndex: 0 } },
        },
      };

std.prune(k.core.v1.list.new([job]))
