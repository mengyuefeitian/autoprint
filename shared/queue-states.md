# Queue States

Allowed states:

- Pending
- Stabilizing
- Queued
- Printing
- Submitted
- Printed
- Retrying
- Failed

Successful transition:

Pending -> Stabilizing -> Queued -> Printing -> Submitted -> Printed

Retry transition:

Pending -> Stabilizing -> Queued -> Printing -> Retrying -> Queued

Failure transition:

Pending -> Stabilizing -> Queued -> Printing -> Retrying -> Failed
Pending -> Stabilizing -> Failed
