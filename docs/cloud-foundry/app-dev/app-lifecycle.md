# Application life-cycle

Factor 9 of the 12 factor app states that [apps must be disposable](https://12factor.net/disposability) and start quickly. This means that apps must perform a graceful shutdown in a way that allows the hosting platform to make the action invisible to the client. Furthermore when running on a PaaS, an app instance must be able to signal to it's hosting platform it is in a healthy state and ready to take traffic.

This doc will explain at a high level the actions which must be taken when engineering an app to run on Cloud Foundry, such that a user or client will not notice an interruption in service during app push, scale, restart and platform upgrades.

## What happens when an app starts

The start process applies to the following events:

- **cf push** - new instance of a new version of the app are started to replace the old version
- **cf scale** - new instance of the app are started
- **cf restart (rolling strategy)** - all instances of the app are replaced
- **Platform upgrade** - Diego cells follow a rolling replacement

At a very high level the [app start process](https://docs.cloudfoundry.org/devguide/deploy-apps/healthchecks.html#healthcheck-lifecycle) follows:

- Schedule decides a instance is needed and instructs the system to start a container
- Container starts on a Diego cell (worker)
- The Diego cell starts a [health check](https://docs.cloudfoundry.org/devguide/deploy-apps/healthchecks.html#types) process
- Application health check passes
- The [Gorouter](https://docs.cloudfoundry.org/concepts/cf-routing-architecture.html) is instructed to add the app into rotation

### Application health checks

Having a health check which only returns true when the app is ready to serve traffic is critical to ensure that adding a container does not cause a client to receive a HTTP error.

Cloud Foundry support 3 types of [health checks](https://docs.cloudfoundry.org/devguide/deploy-apps/healthchecks.html#types):

- **http** - a http request sent to a specific endpoint of the app, with 200 OK expected as the response
- **port** - a TCP can be made on a designated port or ports. **This is the default.**
- **process** - the process is running. E.g the python interpreter is running

It is recommended to use `http` as this is the only option that can ensure the app is ready for traffic. In the case of web apps, both port and process health checks will only confirm that the web server is online, but not that the underlying software is able to respond to traffic. In addition should an app become unresponsive a port health check may return even though the underlying app is no longer able to respond to a request.

## What happens when an app crashes

In the case that an app becomes unresponsive the process is as follows:

- The Gorouter will [transparently retry other instances](https://docs.cloudfoundry.org/concepts/http-routing.html#retry), mark an instance as bad if it cannot make a TCP connection and take the instance out of rotation for 30 seconds
- The app health check fails
- The Gorouter is instructed to remove the app from the routing table
- The app is restarted immediately and [on restart failure it follows a back-off routine](https://docs.cloudfoundry.org/devguide/deploy-apps/healthchecks.html#types:~:text=When%20an%20app%20instance%20fails%2C%20Diego,trying%20to%20restart%20the%20app%20instance.).

In the case that the Gorouter is still able to make a TCP request to an app, for example if a web service is listening, but not able to respond to the request, the Gorouter will continue to send traffic to the instance. To mitigate this it is recommended to to modify the http health check interval below the default of 30 seconds. Depending on the CPU cost of the health check there could be an impact on the platform if the value is set too low.

## What happens when an app stops

The stop process applies to the following events:

- **cf push** - old instances of an app are stopped on a rolling basis and replaced by a new version
- **cf restart (rolling strategy)** - old instances of an app are stopped on a rolling basis
- **cf stop** - all instances of the app are stopped
- **Platform scale down** - Diego cells are drained and removed
- **Platform upgrade** - Diego cells follow a rolling replacement

At a very high level the [app shutdown process](https://docs.cloudfoundry.org/devguide/deploy-apps/app-lifecycle.html#shutdown) is as follows:

- The Gorouter removes the app from its routing table, meaning that no new request will be sent, but outstanding request responses will be honoured
- The scheduler instructs the Diego cell to stop the app
- The container is sent the `SIGTERM` signal, which the app should treat as a soft shutdown event and gracefully complete outstanding requests before stopping cleanly
- If after 10 seconds the container has not exited, Diego then sends a `SIGKILL` which will terminate all processes

Should there be the need to extend the time that apps are given to shutdown this can be [set system wide](https://docs.cloudfoundry.org/devguide/deploy-apps/app-lifecycle.html#shutdown:~:text=containers.graceful_shutdown_interval_in_seconds) but will have the effect that Diego maintenance events could take longer.

Each language will have a different way to respond `SIGTERM`.

### Java shutdown

Java allows the developer to configure [pre-shutdown hooks](https://docs.oracle.com/javase/7/docs/api/java/lang/Runtime.html#addShutdownHook(java.lang.Thread)), to insert logic into the shutdown process.

The default behaviour in Java is as follows:

- JVM receives `SIGTERM`
- All [pre-shutdown hooks](https://docs.oracle.com/javase/7/docs/api/java/lang/Runtime.html#addShutdownHook(java.lang.Thread)) are triggered (if any are defined)
- The JVM will then wait for all [non-daemon threads](https://docs.oracle.com/en/java/javase/12/docs/api/java.base/java/lang/Thread.html) to complete before exiting

The last point is critical, as the JVM will not exit until all theads complete, meaning the app should be designed to take this into account.

#### Spring annotation

Spring apps can use the [@pre-destroy](https://www.baeldung.com/spring-postconstruct-predestroy#preDestroy) annoation to ensure a function is called before exiting.

For Java 9+ the following dependency needs to be added.

```
<dependency>
    <groupId>javax.annotation</groupId>
    <artifactId>javax.annotation-api</artifactId>
    <version>1.3.2</version>
</dependency>
```

### Detecting a SIGKILL

If the following line appears in app logs, then it is proof that an app was forcully shutdown by the system after the app did not respond properly to a `SIGTERM`.

```
OUT Exit status 137 (exceeded 10s graceful shutdown interval)
```

## Testing app behaviour

Should an app team need to test the behaviour to ensure the stop and start events are transparent to a client it is recommended to run `cf restart --strategy rolling` in a dev environment whilst the app is under load. If the app is coded, configured and scaled correctly, then the operation will be invisible to the client.