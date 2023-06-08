# Implementation

Now the concepts are out of the way the rest of this document will be focused on solving a theoretical problem with a bunch of assumed theoretical functional and non-functional requirements.

To help the reader understand what I am trying to build the following statements have been curated.

1. There is **a reason** to have multiple clusters running concurrently, for blast radius on change control and isolation of production data.
1. There is **a reason** to run _sandbox_ clusters that can clone from any cluster; for cost savings and transient use cases.
1. There is **a reason** to have different application configurations in different environments; permits testing a single component in isolation with mocked services.
1. There is **a reason** to run different configurations of infrastructure on each cluster; there should be a baseline assumption all clusters will have the same underlying core resources available in every environment for operational overhead reductions but changes will come in time as the underlying components mature.
1. There is **a reason** to have additional platform and potentially optional components that aren't managed by application teams; Confluent platform, Elastic platform etc.
1. There is **a reason** to have different clusters tracking changes with different cadences and risk appetite, both in the application and platform infrastructure components.

One important take away is to consider the kubernetes platform a rough equivalent to a linux distribution with its opinionated defaults and services. Much like distributions you will need to maintain a support model around multiple simultaneously deployed versions.
