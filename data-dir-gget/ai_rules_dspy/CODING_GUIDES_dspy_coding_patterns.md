# DSPy: Coding Guide, Patterns, and Examples

This document contains implementation details, code snippets, and patterns for building applications with DSPy.

## 1. Setup and Configuration

```python
import dspy
from dspy.teleprompt import MIPROv2, LabeledFewShot

# Configure a Language Model (LM)
# Replace with your specific model provider (OpenAI, Anthropic, Google, etc.)
lm = dspy.Google(model="gemini-2.5-flash") 

dspy.configure(lm=lm)
```

## 2. Signatures

### String-Based (Simple)
Good for quick prototyping or simple tasks.

```python
# Format: "input_field_1, input_field_2 -> output_field"
joker = dspy.Predict("topic -> joke")
response = joker(topic="programming")
print(response.joke)
```

### Class-Based (Structured)
Recommended for production. Supports types, descriptions, and Pydantic models.

```python
import pydantic
from typing import List, Literal

class GrammaticalComponent(pydantic.BaseModel):
    component_type: Literal["subject", "verb", "object", "modifier"]
    extracted_text: str = pydantic.Field(description="Exact substring from original text")

class GrammaticalAnalysis(dspy.Signature):
    """Analyze the sentence to extract grammatical components."""
    
    text: str = dspy.InputField(desc="The source sentence to analyze")
    # Output can be a Pydantic model for strict schema validation
    analysis: List[GrammaticalComponent] = dspy.OutputField(desc="List of extracted components")

# Usage within a module
extractor = dspy.Predict(GrammaticalAnalysis)
```

## 3. Modules

### ChainOfThought
Instructions the LM to "think" before answering.

```python
class CoTAnswerer(dspy.Module):
    def __init__(self):
        super().__init__()
        # 'question -> answer' is the signature
        self.prog = dspy.ChainOfThought("question -> answer")

    def forward(self, question):
        return self.prog(question=question)
```

### ReAct Agent (with Tools)

```python
# 1. Define Tools
def add(a: float, b: float) -> float:
    """Adds two numbers."""
    return a + b

def multiply(a: float, b: float) -> float:
    """Multiplies two numbers."""
    return a * b

# 2. Wrap as DSPy Tools
tools = [dspy.Tool(add), dspy.Tool(multiply)]

# 3. Create Agent
agent = dspy.ReAct("question -> answer", tools=tools, max_iters=5)

# 4. Run
# result = agent(question="What is (5 + 3) * 10?")
# print(result.answer)
```

## 4. Optimization (Teleprompters)

### LabeledFewShot
Basic optimization using a fixed set of examples.

```python
# 1. Create Training Data
trainset = [
    dspy.Example(question="What is 2+2?", answer="4").with_inputs("question"),
    dspy.Example(question="Capital of France?", answer="Paris").with_inputs("question"),
]

# 2. Compile
teleprompter = LabeledFewShot(k=2)
compiled_prog = teleprompter.compile(CoTAnswerer(), trainset=trainset)
```

### MIPROv2 (Advanced)
Optimizes instructions and examples using a metric.

```python
# Metric function
def exact_match_metric(example, pred, trace=None):
    return example.answer.lower() == pred.answer.lower()

# Optimizer
optimizer = MIPROv2(metric=exact_match_metric, auto="light", num_threads=4)

# compiled_prog = optimizer.compile(
#     CoTAnswerer(), 
#     trainset=trainset, 
#     max_bootstrapped_demos=3, 
#     max_labeled_demos=2
# )
```

## 5. Parallel Execution Pattern

For heavy workloads, you can parallelize DSPy calls. This is a helper pattern often used for processing large documents.

```python
from concurrent.futures import ThreadPoolExecutor

def parallelize(fn, max_workers=8):
    """Decorator or wrapper to execute a function in parallel over a list of args."""
    def wrapper(args_list):
        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            # Assumes args_list is a list of dicts meant for **kwargs
            results = list(executor.map(lambda args: fn(**args), args_list))
        return results
    return wrapper

# Usage Example:
# processor = dspy.Predict("content -> summary")
# parallel_processor = parallelize(processor)
# summaries = parallel_processor([{'content': 'chunk1...'}, {'content': 'chunk2...'}])
```

## 6. Observability & Callbacks

Use callbacks to inspect tool execution without modifying tool code.

### Custom Callback Class

```python
import dspy
from dspy.utils.callback import BaseCallback
from typing import Any, Dict, Optional
import logging

logger = logging.getLogger(__name__)

class ToolInspectionCallback(BaseCallback):
    def __init__(self):
        super().__init__()
        self.logs = []

    def on_tool_start(self, call_id: str, instance: Any, inputs: Dict[str, Any]) -> None:
        """Triggered before a tool runs."""
        tool_name = getattr(instance, 'name', str(instance))
        logger.info(f"Starting tool {tool_name} with inputs: {inputs}")
        self.logs.append({"id": call_id, "type": "start", "tool": tool_name, "inputs": inputs})

    def on_tool_end(self, call_id: str, outputs: Any, exception: Optional[Exception] = None) -> None:
        """Triggered after a tool finishes."""
        if exception:
            logger.error(f"Tool {call_id} failed: {exception}")
            self.logs.append({"id": call_id, "type": "error", "error": str(exception)})
        else:
            logger.info(f"Tool {call_id} finished. Output preview: {str(outputs)[:50]}...")
            self.logs.append({"id": call_id, "type": "end", "outputs": outputs})

# Registering the callback
# 1. Global
# dspy.configure(callbacks=[ToolInspectionCallback()])

# 2. Context Manager (Per-request)
# callback_instance = ToolInspectionCallback()
# with dspy.context(callbacks=[callback_instance]):
#     agent(question="Calculate something.")
#
# print(callback_instance.logs) 
```

### Best Practices for Callbacks
1.  **Error Handling**: Wrap logic in `try/except` to prevent callback errors from crashing the agent.
2.  **Immutability**: Do not modify `inputs` or `outputs` dictionaries directly; copy them if you need to alter data for logging.
3.  **Lightweight**: Avoid heavy IO (database writes) directly in the callback thread if possible; use a queue.
