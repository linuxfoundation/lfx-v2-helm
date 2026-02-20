# Entity Design Documentation

This document provides comprehensive guidance for designing entities, API layouts, and OpenFGA types in the LFX v2 platform. It serves as developer-onboarding documentation for understanding how to model entities that integrate with OpenFGA permissions, the Query Service, and platform API design patterns.

## Table of Contents

- [Introduction to OpenFGA Permissions](#introduction-to-openfga-permissions)
- [Entity Types and Access Patterns](#entity-types-and-access-patterns)
- [OpenFGA Type Design](#openfga-type-design)
- [API Design and Entity Mapping](#api-design-and-entity-mapping)
- [Conditional Relationships and Optional Tuples](#conditional-relationships-and-optional-tuples)
- [Collection Attributes and Endpoints](#collection-attributes-and-endpoints)
- [Query Service Integration](#query-service-integration)
- [Best Practices](#best-practices)
- [Reference Examples](#reference-examples)

## Introduction to OpenFGA Permissions

OpenFGA (<https://openfga.dev>) is a relationship-based access control (ReBAC) system, which is a flexible permission system where access is derived from the network of relationships between entities.

This is contrasting with a role-based access control (RBAC) system, which stores and evaluates only *direct* role assignments against individual objects.

For instance, in previous LFX APIs, RBAC provides "project roles" with different policies for how you can interacting with a project: managing committees, scheduling meetings, managing mailing lists, etc. However, it cannot "fan out" access to these project resources on a contextual level. It's the difference between saying, "project _meeting managers_ can access all past meeting recordings for _all_ meetings associated with the project", and saying, "you can access the meeting recording if you were _invited to the meeting_, or if you are currently a _member of the committee_ that held this meeting in the past, or if you are a _meeting manager_ on the project the meeting was held on". Being able to have an access control system that can model and evaluate rich self-service permissions avoids creating multiple "backdoor" systems that use privileged access to circumvent "native" RBAC, and then republish the data with bespoke, per-app access control rules.

Not only does OpenFGA make our permissions more transparent and auditable: having direct, context-aware access to individual objects in LFX opens the door to supporting AI use-cases like MCP servers for managing committees, meetings, and more.

### Core Concepts

Understanding the following core concepts will help you navigate access control in the LFX v2 platform.

**Model**: The schema that defines the types of entities and the kinds of relations users and objects can have with each other (e.g., users can be members of teams, teams can own projects, projects have a parent project). Our model is version-controlled and stored in this repository.

**Tuple**: A relation between two _specific_ objects of any type, conforming to the model, which is stored as a fact in OpenFGA. For example: "user:alice is a member of team:frontend" or "project:platform is the parent of project:web-app". The v2 platform maintains a live sync that indexes LFX data (projects, committees, etc.) into corresponding OpenFGA tuples, in real time.

**Relationship**: A relationship is the traversal or chaining of tuples, as defined by the model, to determine if a given *transitive* relationship exists. For example, if Alice is a member of the frontend team, and the frontend team owns the web-app project, then Alice has an ownership relationship to the web-app project. Throughout this document, when we refer to a "relationship", we always an queried relationship derived from chained tuples and the model definitions, and we will use the term "tuple" when referring to a *direct* relation "fact". The v2 platform uses OpenFGA's "batch check" endpoint to query relationships.

**Permission**: It's not enough to define a model, store tuples, and be able to check relationships: we also need to define *what* relationship is required to perform a given action. For example, a GET request to `/projects/{id}` may be defined to require the relationship "user:{authenticated_user} is a viewer of project:{id}". Defining permissions as relationships is not always straightforward. For instance, to implement a user story "the project admin can create child projects", you might have `/projects/{id}/create_child` endpoint, and define a relation against the project ID extracted from the URL, just like the previous example. However, for a most RESTful API structure, you should instead define the permission that a POST request to `/projects` requires a "writer" relationship of the authenticated user against the `parent_project` attribute of the **POST payload**. In the v2 platform, permissions are defined as Kubernetes RuleSet CRD resources. Unlike the model, which is fully centralized, individual services may define their own rules, but the *enforcement* of the rules is still done centrally, by middleware in our API Gateway, to ensure a consistent, transparent access control paradigm.

### GitHub PR Example

Let's walk through a complete example showing how OpenFGA models, tuples, relationships, and permissions work together for a simplified, GitHub-like pull request system.

#### Model Definition

First, we define the OpenFGA model that describes relations which can be queried against any given object type, any tuples that can be created (indicated by the brackets) and how to chain these, including across types (indicated by the "from" keyword):

```
type organization
  relations
    define owner: [user]
    define member: [user] or owner 

type repository
  relations
    define organization: [organization]
    define writer: [user] or owner from organization
    # Unlike writer, we don't inherit readers from organization members, because
    # this depends on a "condition": the access control settings of the repo.
    # More on this later.
    define reader: [user:*] or [user] or writer

type pullrequest
  relations
    define repository: [repository]
    define author: [user]
    define writer: writer from repository
    define closer: author or writer
    define reader: author or writer or reader from repository
```

Considerations:
- There is no "singleton" relation definition, for example, that a pull request only may have (or must have) exactly **one** repository relation. These kinds of data constraints are enforced by the system that creates and deletes tuples into OpenFGA, not by OpenFGA itself.
- Ordinarily, "greater" relations will explicitly cascade into "lesser" relations (owner → writer → reader), because any given permission (the allow/deny rule defined for a given URL and method) should only check a _single_ relationship. Rather than "writers or readers can GET this resource", you want "readers can GET this resource", and then you include writers as having the readers relation automatically. This also is why a relation like "closer" is defined in the model: it's just an abstraction over two other relations, so that the permission can be defined with only a single relationship to check.

#### Permissions Definition

Next, we would define what relationships are required for each Pull Request API method & endpoint. (The following statements are simplifications of the actual RuleSet DSL.)

```plain
# Any repo reader can create a PR.
POST {"repo_id": {id}, ...} => /pullrequests: reader on repository:{id}
# Any reader on the PR can create a comment on it.
POST {"pullrequest_id": {id}, "body": ...} => /pr_comments: reader on pullrequest:{id}
# Any writer on the PR can merge it.
POST => /pullrequests/{id}/merge: writer on pullrequest:{id}
# Closing the PR uses a special "closer" relation which allows the author to
# close their own PR, even if they have no write access to the repo/PR. POST =>
/pullrequests/{id}/close: closer on pullrequest:{id}
```

#### Sample Tuples

Now we see what tuples (direct relationships) would support relationship checks. These are maintained in OpenFGA by mapping or transforming the live data as it is created and updated.

```
# Organization data
user:alice owner organization:linux-foundation
user:bob member organization:linux-foundation
user:charlie member organization:linux-foundation

# Repository
organization:linux-foundation organization repository:lfx-platform
user:charlie reader repository:lfx-platform
user:dave reader repository:lfx-platform

# Pull Request
repository:lfx-platform repository pullrequest:456
user:charlie author pullrequest:456
```

#### Relationship Resolution

From these tuples, OpenFGA would dynamically compute relationships when checked:

**For pullrequest:456:**
- `user:alice` has `writer` (owner org:linux-foundation → writer repo:lfx-platform → writer)  
- `user:alice` has `closer` (writer → closer))
- `user:alice` has `reader` (writer → reader)
- `user:bob` has NO relations (org members have no implicit repo relations)
- `user:charlie` does NOT have `writer`
- `user:charlie` has `closer` (author → closer)
- `user:charlie` has `reader` (author → reader OR reader repo:lfx-platform → reader)
- `user:dave` has only `reader` (reader repo:lfx-platform → reader)
- `user:eve` does NOT have `closer` (has writer but not author)

This demonstrates how OpenFGA's relationship-based model creates a flexible permission system where access is derived from the network of relationships between entities.

Contrasted with a role-based access control system, which only supports storing and checking *direct* role assignments against objects. For instance, in LFX, "project roles"  ability to grant contextual access resources within that project to committee members, meeting participants, and such within a project.

## Entity Types and Access Patterns

Not all objects in LFX need, or should have, OpenFGA types.

### When to Create OpenFGA Types

**Create OpenFGA types when entities need "extra access" patterns** - that is, when permissions cannot be wholly expressed through relationships to parent resources.

#### Examples of Entities Requiring OpenFGA Types

1. **Projects**: Need direct ownership, membership, and access controls
2. **Committees**: Require explicit membership and role-based permissions
3. **Voting Polls**: Need voter eligibility and results access controls
4. **Past Meetings**: Require participant permissions

#### Examples of Entities NOT Requiring OpenFGA Types

1. **Meeting Artifacts**: Access defined by user relation to past meeting
2. **Project Domains**: Access defined by user relation to project
3. **Committee Members**: Represented as the "member" relation/tuple on the committee type
4. **User Profiles**: User **is** a "type", but it has no relations defined against it. Access to other user's profiles (name, email) is primarily via the authenticated user's relation to search across objects (committees, mailing lists) which themselves hold collections of users (denormalized user profiles). Moreover, access to SSO profiles or CDP/CM profiles, when implemented, would be a global "team relation" check, not a per-object-ID relation check against individual user-type objects.

### Entity Types for Indexing and Query Service

Even entities that don't require OpenFGA types still need **entity type classifications** for:

- **Indexing**: Organizing data in OpenSearch with proper type mappings
- **Query Service**: Enabling type-specific search and filtering
- **API Design**: Consistent endpoint structure and foreign-key naming conventions

Because of the importance of these platform-wide services, type names for these other objects **must be unique** within the platform, even though they do not show up in the OpenFGA model.

TODO: examples of type naming

## Conditional Relationships and Optional Tuples

TODO: explain conditional access (extend "repo viewer" use case from PR with public/private/internal repos)

TODO: compare 3 ways to model conditional access: filtered [user] mappings (redundant, lots of extra tuples), native Conditional-Tuples OpenFGA feature (need to change all OpenFGA consumers to consume data payloads), and optional relationship tuples that can reference existing user tuples without redundancy (e.g. org_for_internal_access: [org] -> members from org_for_internal_access)—which is our method of choice currently.

## Best practices

### Conventions for common relation names

TODO: introduce concept of "viewer" vs. "auditor" convention: viewer has limited read access to the object, and viewer access ordinarily is NOT propagated to child resources. Auditor provides "full" read access, and ordinarily DOES propagate to child resources.

TODO: rationale for "writer" relation and mapping it to business terminology (admin). Possibly mention ambiguity of "maintainer" (as project relation, vs. member relation against committee of certain type).

TODO: rationale for "owner" relation on projects

### When to create separate collection endpoints

TODO: compare/contrast an in-resource arrays (like project writers/auditors) vs. a nested "REST collection" endpoint (like committee members). How this impacts both indexing (types) and user profile searches.

### When to split an object across multiple attribute sets

TODO: explain how "business" entities (like projects) may need attributes split across multiple API endpoints in order to provide granular access to certain properties to different-relation users (legal admin vs. regular admin for project fields).

TODO: review remaining doc (AI generated)

### OpenFGA Type Design

1. **Start Simple**: Begin with basic viewer/writer/owner patterns
2. **Inherit When Possible**: Leverage parent relationships to reduce complexity
3. **Compose Permissions**: Build complex permissions from simpler building blocks
4. **Test Relationships**: Use OpenFGA CLI to verify tuple resolution and relationship queries

### API Design

1. **Consistent Patterns**: Follow established endpoint patterns across services
2. **Permission Alignment**: Ensure API permissions match required OpenFGA relationships exactly
3. **Resource Hierarchy**: Structure URLs to reflect entity relationships
4. **Error Handling**: Provide clear authorization error messages

### Entity Modeling

1. **Identify Access Patterns**: Map out who needs what access before designing types
2. **Consider Lifecycle**: Design for entity creation, updates, and deletion flows
3. **Plan for Scale**: Consider performance implications of complex relationship graphs
4. **Document Decisions**: Maintain clear documentation of entity design choices

### Common Pitfalls

1. **Over-Engineering Types**: Don't create OpenFGA types for entities that can inherit permissions
2. **Missing Hierarchies**: Remember to include parent tuples for relationship inheritance
3. **Inconsistent Naming**: Use consistent relation names across similar entity types
4. **Complex Conditionals**: Avoid overly complex conditional relationships that are hard to reason about

## Reference Examples

### Complete Example: Voting Service

For a comprehensive example of entity design, API contracts, and OpenFGA integration, see:
[LFX v2 Voting Service API Contracts](https://github.com/linuxfoundation/lfx-v2-voting-service/blob/main/docs/api-contracts.md)

This example demonstrates:
- OpenFGA type definitions for polls, votes, and results
- API endpoint design with proper authorization mapping
- Collection vs. individual entity access patterns
- Conditional permissions based on poll state and user eligibility

### Additional Resources

- [OpenFGA Documentation](https://openfga.dev/docs/)
- [LFX v2 OpenFGA Configuration](./openfga.md)
- [Query Service Documentation](https://github.com/linuxfoundation/lfx-v2-query-service)
- [Platform Services Overview](https://github.com/linuxfoundation/lfx-v2-platform-services)

---

This documentation should be updated as entity design patterns evolve and new use cases emerge. When designing new entities, always consider the principles outlined here and seek architectural review for complex authorization requirements.
