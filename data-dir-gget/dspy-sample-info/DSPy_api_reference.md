# Directory Structure
_Includes files where the actual content might be omitted. This way the LLM can still use the file structure to understand the project._
```
.
└── docs
    └── docs
        └── api
            ├── adapters
            │   ├── Adapter.md
            │   ├── ChatAdapter.md
            │   ├── JSONAdapter.md
            │   └── TwoStepAdapter.md
            ├── evaluation
            │   ├── CompleteAndGrounded.md
            │   ├── Evaluate.md
            │   ├── SemanticF1.md
            │   ├── answer_exact_match.md
            │   └── answer_passage_match.md
            ├── index.md
            ├── models
            │   ├── Embedder.md
            │   └── LM.md
            ├── modules
            │   ├── BestOfN.md
            │   ├── ChainOfThought.md
            │   ├── CodeAct.md
            │   ├── Module.md
            │   ├── MultiChainComparison.md
            │   ├── Parallel.md
            │   ├── Predict.md
            │   ├── ProgramOfThought.md
            │   ├── ReAct.md
            │   └── Refine.md
            ├── optimizers
            │   ├── BetterTogether.md
            │   ├── BootstrapFewShot.md
            │   ├── BootstrapFewShotWithRandomSearch.md
            │   ├── BootstrapFinetune.md
            │   ├── BootstrapRS.md
            │   ├── COPRO.md
            │   ├── Ensemble.md
            │   ├── InferRules.md
            │   ├── KNN.md
            │   ├── KNNFewShot.md
            │   ├── LabeledFewShot.md
            │   ├── MIPROv2.md
            │   └── SIMBA.md
            ├── primitives
            │   ├── Example.md
            │   ├── History.md
            │   ├── Image.md
            │   ├── Prediction.md
            │   └── Tool.md
            ├── signatures
            │   ├── InputField.md
            │   ├── OutputField.md
            │   └── Signature.md
            ├── tools
            │   ├── ColBERTv2.md
            │   ├── Embeddings.md
            │   └── PythonInterpreter.md
            └── utils
                ├── StatusMessage.md
                ├── StatusMessageProvider.md
                ├── StreamListener.md
                ├── asyncify.md
                ├── configure_cache.md
                ├── disable_litellm_logging.md
                ├── disable_logging.md
                ├── enable_litellm_logging.md
                ├── enable_logging.md
                ├── inspect_history.md
                ├── load.md
                └── streamify.md
```

# File Contents

## File: `docs/docs/api/adapters/Adapter.md`
```
# dspy.Adapter

<!-- START_API_REF -->
::: dspy.Adapter
    handler: python
    options:
        members:
            - __call__
            - acall
            - format
            - format_assistant_message_content
            - format_conversation_history
            - format_demos
            - format_field_description
            - format_field_structure
            - format_task_description
            - format_user_message_content
            - parse
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/adapters/ChatAdapter.md`
```
# dspy.ChatAdapter

<!-- START_API_REF -->
::: dspy.ChatAdapter
    handler: python
    options:
        members:
            - __call__
            - acall
            - format
            - format_assistant_message_content
            - format_conversation_history
            - format_demos
            - format_field_description
            - format_field_structure
            - format_field_with_value
            - format_finetune_data
            - format_task_description
            - format_user_message_content
            - parse
            - user_message_output_requirements
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/adapters/JSONAdapter.md`
```
# dspy.JSONAdapter

<!-- START_API_REF -->
::: dspy.JSONAdapter
    handler: python
    options:
        members:
            - __call__
            - acall
            - format
            - format_assistant_message_content
            - format_conversation_history
            - format_demos
            - format_field_description
            - format_field_structure
            - format_field_with_value
            - format_finetune_data
            - format_task_description
            - format_user_message_content
            - parse
            - user_message_output_requirements
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/adapters/TwoStepAdapter.md`
```
# dspy.TwoStepAdapter

<!-- START_API_REF -->
::: dspy.TwoStepAdapter
    handler: python
    options:
        members:
            - __call__
            - acall
            - format
            - format_assistant_message_content
            - format_conversation_history
            - format_demos
            - format_field_description
            - format_field_structure
            - format_task_description
            - format_user_message_content
            - parse
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/evaluation/CompleteAndGrounded.md`
```
# dspy.evaluate.CompleteAndGrounded

<!-- START_API_REF -->
::: dspy.evaluate.CompleteAndGrounded
    handler: python
    options:
        members:
            - __call__
            - acall
            - batch
            - deepcopy
            - dump_state
            - forward
            - get_lm
            - inspect_history
            - load
            - load_state
            - map_named_predictors
            - named_parameters
            - named_predictors
            - named_sub_modules
            - parameters
            - predictors
            - reset_copy
            - save
            - set_lm
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/evaluation/Evaluate.md`
```
# dspy.Evaluate

<!-- START_API_REF -->
::: dspy.Evaluate
    handler: python
    options:
        members:
            - __call__
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/evaluation/SemanticF1.md`
```
# dspy.evaluate.SemanticF1

<!-- START_API_REF -->
::: dspy.evaluate.SemanticF1
    handler: python
    options:
        members:
            - __call__
            - acall
            - batch
            - deepcopy
            - dump_state
            - forward
            - get_lm
            - inspect_history
            - load
            - load_state
            - map_named_predictors
            - named_parameters
            - named_predictors
            - named_sub_modules
            - parameters
            - predictors
            - reset_copy
            - save
            - set_lm
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/evaluation/answer_exact_match.md`
```
# dspy.evaluate.answer_exact_match

<!-- START_API_REF -->
::: dspy.evaluate.answer_exact_match
    handler: python
    options:
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/evaluation/answer_passage_match.md`
```
# dspy.evaluate.answer_passage_match

<!-- START_API_REF -->
::: dspy.evaluate.answer_passage_match
    handler: python
    options:
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/index.md`
```
# API Reference

Welcome to the DSPy API reference documentation. This section provides detailed information about DSPy's classes, modules, and functions.```

## File: `docs/docs/api/models/Embedder.md`
```
# dspy.Embedder

<!-- START_API_REF -->
::: dspy.Embedder
    handler: python
    options:
        members:
            - __call__
            - acall
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/models/LM.md`
```
# dspy.LM

<!-- START_API_REF -->
::: dspy.LM
    handler: python
    options:
        members:
            - __call__
            - acall
            - aforward
            - copy
            - dump_state
            - finetune
            - forward
            - infer_provider
            - inspect_history
            - kill
            - launch
            - reinforce
            - update_global_history
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/modules/BestOfN.md`
```
# dspy.BestOfN

<!-- START_API_REF -->
::: dspy.BestOfN
    handler: python
    options:
        members:
            - __call__
            - acall
            - batch
            - deepcopy
            - dump_state
            - forward
            - get_lm
            - inspect_history
            - load
            - load_state
            - map_named_predictors
            - named_parameters
            - named_predictors
            - named_sub_modules
            - parameters
            - predictors
            - reset_copy
            - save
            - set_lm
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/modules/ChainOfThought.md`
```
# dspy.ChainOfThought

<!-- START_API_REF -->
::: dspy.ChainOfThought
    handler: python
    options:
        members:
            - __call__
            - acall
            - aforward
            - batch
            - deepcopy
            - dump_state
            - forward
            - get_lm
            - inspect_history
            - load
            - load_state
            - map_named_predictors
            - named_parameters
            - named_predictors
            - named_sub_modules
            - parameters
            - predictors
            - reset_copy
            - save
            - set_lm
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/modules/CodeAct.md`
```
# dspy.CodeAct

<!-- START_API_REF -->
::: dspy.CodeAct
    handler: python
    options:
        members:
            - __call__
            - batch
            - deepcopy
            - dump_state
            - get_lm
            - inspect_history
            - load
            - load_state
            - map_named_predictors
            - named_parameters
            - named_predictors
            - named_sub_modules
            - parameters
            - predictors
            - reset_copy
            - save
            - set_lm
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
<!-- END_API_REF -->

# CodeAct

CodeAct is a DSPy module that combines code generation with tool execution to solve problems. It generates Python code snippets that use provided tools and the Python standard library to accomplish tasks.

## Basic Usage

Here's a simple example of using CodeAct:

```python
import dspy
from dspy.predict import CodeAct

# Define a simple tool function
def factorial(n: int) -> int:
    """Calculate the factorial of a number."""
    if n == 1:
        return 1
    return n * factorial(n-1)

# Create a CodeAct instance
act = CodeAct("n->factorial_result", tools=[factorial])

# Use the CodeAct instance
result = act(n=5)
print(result) # Will calculate factorial(5) = 120
```

## How It Works

CodeAct operates in an iterative manner:

1. Takes input parameters and available tools
2. Generates Python code snippets that use these tools
3. Executes the code using a Python sandbox
4. Collects the output and determines if the task is complete
5. Answer the original question based on the collected information

## ⚠️ Limitations

### Only accepts pure functions as tools (no callable objects)

The following example does not work due to the usage of a callable object.

```python
# ❌ NG
class Add():
    def __call__(self, a: int, b: int):
        return a + b

dspy.CodeAct("question -> answer", tools=[Add()])
```

### External libraries cannot be used

The following example does not work due to the usage of the external library `numpy`.

```python
# ❌ NG
import numpy as np

def exp(i: int):
    return np.exp(i)

dspy.CodeAct("question -> answer", tools=[exp])
```

### All dependent functions need to be passed to `CodeAct`

Functions that depend on other functions or classes not passed to `CodeAct` cannot be used. The following example does not work because the tool functions depend on other functions or classes that are not passed to `CodeAct`, such as `Profile` or `secret_function`.

```python
# ❌ NG
from pydantic import BaseModel

class Profile(BaseModel):
    name: str
    age: int
    
def age(profile: Profile):
    return 

def parent_function():
    print("Hi!")

def child_function():
    parent_function()

dspy.CodeAct("question -> answer", tools=[age, child_function])
```

Instead, the following example works since all necessary tool functions are passed to `CodeAct`:

```python
# ✅ OK

def parent_function():
    print("Hi!")

def child_function():
    parent_function()

dspy.CodeAct("question -> answer", tools=[parent_function, child_function])
```
```

## File: `docs/docs/api/modules/Module.md`
```
# dspy.Module

<!-- START_API_REF -->
::: dspy.Module
    handler: python
    options:
        members:
            - __call__
            - acall
            - batch
            - deepcopy
            - dump_state
            - get_lm
            - inspect_history
            - load
            - load_state
            - map_named_predictors
            - named_parameters
            - named_predictors
            - named_sub_modules
            - parameters
            - predictors
            - reset_copy
            - save
            - set_lm
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/modules/MultiChainComparison.md`
```
# dspy.MultiChainComparison

<!-- START_API_REF -->
::: dspy.MultiChainComparison
    handler: python
    options:
        members:
            - __call__
            - acall
            - batch
            - deepcopy
            - dump_state
            - forward
            - get_lm
            - inspect_history
            - load
            - load_state
            - map_named_predictors
            - named_parameters
            - named_predictors
            - named_sub_modules
            - parameters
            - predictors
            - reset_copy
            - save
            - set_lm
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/modules/Parallel.md`
```
# dspy.Parallel

<!-- START_API_REF -->
::: dspy.Parallel
    handler: python
    options:
        members:
            - __call__
            - forward
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/modules/Predict.md`
```
# dspy.Predict

<!-- START_API_REF -->
::: dspy.Predict
    handler: python
    options:
        members:
            - __call__
            - acall
            - aforward
            - batch
            - deepcopy
            - dump_state
            - forward
            - get_config
            - get_lm
            - inspect_history
            - load
            - load_state
            - map_named_predictors
            - named_parameters
            - named_predictors
            - named_sub_modules
            - parameters
            - predictors
            - reset
            - reset_copy
            - save
            - set_lm
            - update_config
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/modules/ProgramOfThought.md`
```
# dspy.ProgramOfThought

<!-- START_API_REF -->
::: dspy.ProgramOfThought
    handler: python
    options:
        members:
            - __call__
            - acall
            - batch
            - deepcopy
            - dump_state
            - forward
            - get_lm
            - inspect_history
            - load
            - load_state
            - map_named_predictors
            - named_parameters
            - named_predictors
            - named_sub_modules
            - parameters
            - predictors
            - reset_copy
            - save
            - set_lm
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/modules/ReAct.md`
```
# dspy.ReAct

<!-- START_API_REF -->
::: dspy.ReAct
    handler: python
    options:
        members:
            - __call__
            - acall
            - aforward
            - batch
            - deepcopy
            - dump_state
            - forward
            - get_lm
            - inspect_history
            - load
            - load_state
            - map_named_predictors
            - named_parameters
            - named_predictors
            - named_sub_modules
            - parameters
            - predictors
            - reset_copy
            - save
            - set_lm
            - truncate_trajectory
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/modules/Refine.md`
```
# dspy.Refine

<!-- START_API_REF -->
::: dspy.Refine
    handler: python
    options:
        members:
            - __call__
            - acall
            - batch
            - deepcopy
            - dump_state
            - forward
            - get_lm
            - inspect_history
            - load
            - load_state
            - map_named_predictors
            - named_parameters
            - named_predictors
            - named_sub_modules
            - parameters
            - predictors
            - reset_copy
            - save
            - set_lm
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/optimizers/BetterTogether.md`
```
# dspy.BetterTogether

<!-- START_API_REF -->
::: dspy.BetterTogether
    handler: python
    options:
        members:
            - compile
            - get_params
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/optimizers/BootstrapFewShot.md`
```
# dspy.BootstrapFewShot

<!-- START_API_REF -->
::: dspy.BootstrapFewShot
    handler: python
    options:
        members:
            - compile
            - get_params
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/optimizers/BootstrapFewShotWithRandomSearch.md`
```
# dspy.BootstrapFewShotWithRandomSearch

<!-- START_API_REF -->
::: dspy.BootstrapFewShotWithRandomSearch
    handler: python
    options:
        members:
            - compile
            - get_params
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/optimizers/BootstrapFinetune.md`
```
# dspy.BootstrapFinetune

<!-- START_API_REF -->
::: dspy.BootstrapFinetune
    handler: python
    options:
        members:
            - compile
            - convert_to_lm_dict
            - finetune_lms
            - get_params
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/optimizers/BootstrapRS.md`
```
# dspy.BootstrapRS

<!-- START_API_REF -->
::: dspy.BootstrapRS
    handler: python
    options:
        members:
            - compile
            - get_params
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/optimizers/COPRO.md`
```
# dspy.COPRO

<!-- START_API_REF -->
::: dspy.COPRO
    handler: python
    options:
        members:
            - compile
            - get_params
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/optimizers/Ensemble.md`
```
# dspy.Ensemble

<!-- START_API_REF -->
::: dspy.Ensemble
    handler: python
    options:
        members:
            - compile
            - get_params
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/optimizers/InferRules.md`
```
# dspy.InferRules

<!-- START_API_REF -->
::: dspy.InferRules
    handler: python
    options:
        members:
            - compile
            - evaluate_program
            - format_examples
            - get_params
            - get_predictor_demos
            - induce_natural_language_rules
            - update_program_instructions
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/optimizers/KNN.md`
```
# dspy.KNN

<!-- START_API_REF -->
::: dspy.KNN
    handler: python
    options:
        members:
            - __call__
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/optimizers/KNNFewShot.md`
```
# dspy.KNNFewShot

<!-- START_API_REF -->
::: dspy.KNNFewShot
    handler: python
    options:
        members:
            - compile
            - get_params
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/optimizers/LabeledFewShot.md`
```
# dspy.LabeledFewShot

<!-- START_API_REF -->
::: dspy.LabeledFewShot
    handler: python
    options:
        members:
            - compile
            - get_params
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/optimizers/MIPROv2.md`
```
# dspy.MIPROv2

`MIPROv2` (<u>M</u>ultiprompt <u>I</u>nstruction <u>PR</u>oposal <u>O</u>ptimizer Version 2) is an prompt optimizer capable of optimizing both instructions and few-shot examples jointly. It does this by bootstrapping few-shot example candidates, proposing instructions grounded in different dynamics of the task, and finding an optimized combination of these options using Bayesian Optimization. It can be used for optimizing few-shot examples & instructions jointly, or just instructions for 0-shot optimization.

<!-- START_API_REF -->
::: dspy.MIPROv2
    handler: python
    options:
        members:
            - compile
            - get_params
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->

## Example Usage

The program below shows optimizing a math program with MIPROv2

```python
import dspy
from dspy.datasets.gsm8k import GSM8K, gsm8k_metric

# Import the optimizer
from dspy.teleprompt import MIPROv2

# Initialize the LM
lm = dspy.LM('openai/gpt-4o-mini', api_key='YOUR_OPENAI_API_KEY')
dspy.configure(lm=lm)

# Initialize optimizer
teleprompter = MIPROv2(
    metric=gsm8k_metric,
    auto="medium", # Can choose between light, medium, and heavy optimization runs
)

# Optimize program
print(f"Optimizing program with MIPROv2...")
gsm8k = GSM8K()
optimized_program = teleprompter.compile(
    dspy.ChainOfThought("question -> answer"),
    trainset=gsm8k.train,
    requires_permission_to_run=False,
)

# Save optimize program for future use
optimized_program.save(f"optimized.json")
```

## How `MIPROv2` works

At a high level, `MIPROv2` works by creating both few-shot examples and new instructions for each predictor in your LM program, and then searching over these using Bayesian Optimization to find the best combination of these variables for your program.  If you want a visual explanation check out this [twitter thread](https://x.com/michaelryan207/status/1804189184988713065).

These steps are broken down in more detail below:

1) **Bootstrap Few-Shot Examples**: Randomly samples examples from your training set, and run them through your LM program. If the output from the program is correct for this example, it is kept as a valid few-shot example candidate. Otherwise, we try another example until we've curated the specified amount of few-shot example candidates. This step creates `num_candidates` sets of `max_bootstrapped_demos` bootstrapped examples and `max_labeled_demos` basic examples sampled from the training set.

2) **Propose Instruction Candidates**. The instruction proposer includes (1) a generated summary of properties of the training dataset, (2) a generated summary of your LM program's code and the specific predictor that an instruction is being generated for, (3) the previously bootstrapped few-shot examples to show reference inputs / outputs for a given predictor and (4) a randomly sampled tip for generation (i.e. "be creative", "be concise", etc.) to help explore the feature space of potential instructions.  This context is provided to a `prompt_model` which writes high quality instruction candidates.

3) **Find an Optimized Combination of Few-Shot Examples & Instructions**. Finally, we use Bayesian Optimization to choose which combinations of instructions and demonstrations work best for each predictor in our program. This works by running a series of `num_trials` trials, where a new set of prompts are evaluated over our validation set at each trial. The new set of prompts are only evaluated on a minibatch of size `minibatch_size` at each trial (when `minibatch`=`True`). The best averaging set of prompts is then evalauted on the full validation set every `minibatch_full_eval_steps`. At the end of the optimization process, the LM program with the set of prompts that performed best on the full validation set is returned.

For those interested in more details, more information on `MIPROv2` along with a study on `MIPROv2` compared with other DSPy optimizers can be found in [this paper](https://arxiv.org/abs/2406.11695).
```

## File: `docs/docs/api/optimizers/SIMBA.md`
```
# dspy.SIMBA

<!-- START_API_REF -->
::: dspy.SIMBA
    handler: python
    options:
        members:
            - compile
            - get_params
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
<!-- END_API_REF -->

## Example Usage

```python
optimizer = dspy.SIMBA(metric=your_metric)
optimized_program = optimizer.compile(your_program, trainset=your_trainset)

# Save optimize program for future use
optimized_program.save(f"optimized.json")
```
```

## File: `docs/docs/api/primitives/Example.md`
```
# dspy.Example

<!-- START_API_REF -->
::: dspy.Example
    handler: python
    options:
        members:
            - copy
            - get
            - inputs
            - items
            - keys
            - labels
            - toDict
            - values
            - with_inputs
            - without
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/primitives/History.md`
```
# dspy.History

<!-- START_API_REF -->
::: dspy.History
    handler: python
    options:
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/primitives/Image.md`
```
# dspy.Image

<!-- START_API_REF -->
::: dspy.Image
    handler: python
    options:
        members:
            - description
            - extract_custom_type_from_annotation
            - format
            - from_PIL
            - from_file
            - from_url
            - serialize_model
            - validate_input
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/primitives/Prediction.md`
```
# dspy.Prediction

<!-- START_API_REF -->
::: dspy.Prediction
    handler: python
    options:
        members:
            - copy
            - from_completions
            - get
            - get_lm_usage
            - inputs
            - items
            - keys
            - labels
            - set_lm_usage
            - toDict
            - values
            - with_inputs
            - without
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/primitives/Tool.md`
```
# dspy.Tool

<!-- START_API_REF -->
::: dspy.Tool
    handler: python
    options:
        members:
            - __call__
            - acall
            - description
            - extract_custom_type_from_annotation
            - format
            - format_as_litellm_function_call
            - from_langchain
            - from_mcp_tool
            - serialize_model
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/signatures/InputField.md`
```
# dspy.InputField

<!-- START_API_REF -->
::: dspy.InputField
    handler: python
    options:
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/signatures/OutputField.md`
```
# dspy.OutputField

<!-- START_API_REF -->
::: dspy.OutputField
    handler: python
    options:
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/signatures/Signature.md`
```
# dspy.Signature

<!-- START_API_REF -->
::: dspy.Signature
    handler: python
    options:
        members:
            - append
            - delete
            - dump_state
            - equals
            - insert
            - load_state
            - prepend
            - with_instructions
            - with_updated_fields
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/tools/ColBERTv2.md`
```
# dspy.ColBERTv2

<!-- START_API_REF -->
::: dspy.ColBERTv2
    handler: python
    options:
        members:
            - __call__
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/tools/Embeddings.md`
```
# dspy.retrievers.Embeddings

<!-- START_API_REF -->
::: dspy.Embeddings
    handler: python
    options:
        members:
            - __call__
            - forward
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/tools/PythonInterpreter.md`
```
# dspy.PythonInterpreter

<!-- START_API_REF -->
::: dspy.PythonInterpreter
    handler: python
    options:
        members:
            - __call__
            - execute
            - shutdown
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/utils/StatusMessage.md`
```
# dspy.streaming.StatusMessage

<!-- START_API_REF -->
::: dspy.streaming.StatusMessage
    handler: python
    options:
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/utils/StatusMessageProvider.md`
```
# dspy.streaming.StatusMessageProvider

<!-- START_API_REF -->
::: dspy.streaming.StatusMessageProvider
    handler: python
    options:
        members:
            - lm_end_status_message
            - lm_start_status_message
            - module_end_status_message
            - module_start_status_message
            - tool_end_status_message
            - tool_start_status_message
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/utils/StreamListener.md`
```
# dspy.streaming.StreamListener

<!-- START_API_REF -->
::: dspy.streaming.StreamListener
    handler: python
    options:
        members:
            - flush
            - receive
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/utils/asyncify.md`
```
# dspy.asyncify

<!-- START_API_REF -->
::: dspy.asyncify
    handler: python
    options:
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/utils/configure_cache.md`
```
# dspy.configure_cache

<!-- START_API_REF -->
::: dspy.configure_cache
    handler: python
    options:
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/utils/disable_litellm_logging.md`
```
# dspy.disable_litellm_logging

<!-- START_API_REF -->
::: dspy.disable_litellm_logging
    handler: python
    options:
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/utils/disable_logging.md`
```
# dspy.disable_logging

<!-- START_API_REF -->
::: dspy.disable_logging
    handler: python
    options:
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/utils/enable_litellm_logging.md`
```
# dspy.enable_litellm_logging

<!-- START_API_REF -->
::: dspy.enable_litellm_logging
    handler: python
    options:
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/utils/enable_logging.md`
```
# dspy.enable_logging

<!-- START_API_REF -->
::: dspy.enable_logging
    handler: python
    options:
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/utils/inspect_history.md`
```
# dspy.inspect_history

<!-- START_API_REF -->
::: dspy.inspect_history
    handler: python
    options:
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/utils/load.md`
```
# dspy.load

<!-- START_API_REF -->
::: dspy.load
    handler: python
    options:
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```

## File: `docs/docs/api/utils/streamify.md`
```
# dspy.streamify

<!-- START_API_REF -->
::: dspy.streamify
    handler: python
    options:
        show_source: true
        show_root_heading: true
        heading_level: 2
        docstring_style: google
        show_root_full_path: true
        show_object_full_path: false
        separate_signature: false
        inherited_members: true
:::
<!-- END_API_REF -->
```
