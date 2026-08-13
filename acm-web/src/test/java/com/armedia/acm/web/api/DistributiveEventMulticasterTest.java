package com.armedia.acm.web.api;

/*-
 * #%L
 * ACM Shared Web Artifacts
 * %%
 * Copyright (C) 2014 - 2018 ArkCase LLC
 * %%
 * This file is part of the ArkCase software. 
 * 
 * If the software was purchased under a paid ArkCase license, the terms of 
 * the paid license agreement will prevail.  Otherwise, the software is 
 * provided under the following open source license terms:
 * 
 * ArkCase is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *  
 * ArkCase is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with ArkCase. If not, see <http://www.gnu.org/licenses/>.
 * #L%
 */

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertSame;
import static org.junit.Assert.assertTrue;

import org.junit.Before;
import org.junit.Test;
import org.springframework.context.ApplicationEvent;
import org.springframework.context.ApplicationListener;
import org.springframework.context.event.ApplicationEventMulticaster;
import org.springframework.core.ResolvableType;

import java.util.ArrayList;
import java.util.List;
import java.util.function.Predicate;

/**
 * Unit tests for {@link DistributiveEventMulticaster}.
 * <p>
 * The subject of these tests is the pair of methods that Spring 5.3.5 added to
 * {@link ApplicationEventMulticaster} and that this hand-written implementation therefore had to implement:
 * {@code removeApplicationListeners(Predicate)}, which must delegate to both wrapped multicasters exactly as the
 * pre-existing {@code removeApplicationListener} does, and {@code removeApplicationListenerBeans(Predicate)},
 * which must stay a deliberate no-op exactly as the pre-existing {@code removeApplicationListenerBean} does,
 * because this multicaster never tracks listener bean names. Both properties are behavioural conventions of the
 * class rather than anything the compiler can check, so they are pinned here: a future "tidy-up" that made the
 * bean-name variant delegate, or that dropped one of the two delegations, would break these tests.
 * <p>
 * The surrounding delegation contract is exercised alongside them, so the recorded call order proves the two new
 * methods behave like their established siblings rather than merely being present.
 * <p>
 * The delegates are hand-written recording doubles rather than a mocking framework: the assertions are about
 * argument identity and cross-delegate ordering, which a single shared invocation log expresses directly, and
 * this module needs no mocking dependency for it.
 */
public class DistributiveEventMulticasterTest
{
    private static final String ASYNC = "async";
    private static final String SYNC = "sync";

    private List<String> invocations;
    private RecordingEventMulticaster asyncMulticaster;
    private RecordingEventMulticaster syncMulticaster;
    private DistributiveEventMulticaster distributiveEventMulticaster;

    @Before
    public void setUp()
    {
        invocations = new ArrayList<>();
        asyncMulticaster = new RecordingEventMulticaster(ASYNC, invocations);
        syncMulticaster = new RecordingEventMulticaster(SYNC, invocations);

        distributiveEventMulticaster = new DistributiveEventMulticaster();
        distributiveEventMulticaster.setAsyncEventMulticaster(asyncMulticaster);
        distributiveEventMulticaster.setSyncEventMulticaster(syncMulticaster);
    }

    /**
     * The Spring 5.3.5 predicate-based removal must reach BOTH delegates, must pass through the very same
     * predicate instance to each (no wrapping, no copying, no re-derivation), and must do so asynchronous first
     * then synchronous - the order the pre-existing single-listener removal uses.
     */
    @Test
    public void removeApplicationListenersDelegatesTheSamePredicateAsyncThenSync()
    {
        Predicate<ApplicationListener<?>> predicate = listener -> true;

        distributiveEventMulticaster.removeApplicationListeners(predicate);

        assertEquals("both delegates must be called exactly once", 2, invocations.size());
        assertEquals(ASYNC + ":removeApplicationListeners", invocations.get(0));
        assertEquals(SYNC + ":removeApplicationListeners", invocations.get(1));
        assertSame("the async delegate must receive the caller's predicate instance", predicate,
                asyncMulticaster.getRemovedListenerPredicate());
        assertSame("the sync delegate must receive the very same predicate instance", predicate,
                syncMulticaster.getRemovedListenerPredicate());
    }

    /**
     * Listener-BEAN removal by predicate is intentionally inert, matching {@code removeApplicationListenerBean}:
     * this multicaster resolves listeners as objects and holds no bean names, so there is nothing to filter.
     * Neither delegate may be touched - delegating would hand the bean-name predicate to multicasters that never
     * received those bean names in the first place.
     */
    @Test
    public void removeApplicationListenerBeansIsANoOpOnBothDelegates()
    {
        distributiveEventMulticaster.removeApplicationListenerBeans(beanName -> true);

        assertTrue("removeApplicationListenerBeans must not reach any delegate", invocations.isEmpty());
        assertEquals(0, asyncMulticaster.getRemovedBeanPredicateCount());
        assertEquals(0, syncMulticaster.getRemovedBeanPredicateCount());
    }

    /**
     * The pre-existing single-listener removal, kept alongside the predicate variant so the delegation order
     * asserted above is demonstrably the class's established convention and not an arbitrary choice.
     */
    @Test
    public void removeApplicationListenerDelegatesAsyncThenSync()
    {
        ApplicationListener<ApplicationEvent> listener = event -> {
        };

        distributiveEventMulticaster.removeApplicationListener(listener);

        assertEquals(2, invocations.size());
        assertEquals(ASYNC + ":removeApplicationListener", invocations.get(0));
        assertEquals(SYNC + ":removeApplicationListener", invocations.get(1));
    }

    /**
     * Bean-name registration and removal are both inert for the same reason as the predicate variant.
     */
    @Test
    public void listenerBeanNameMethodsAreNoOps()
    {
        distributiveEventMulticaster.addApplicationListenerBean("someListenerBean");
        distributiveEventMulticaster.removeApplicationListenerBean("someListenerBean");

        assertTrue("bean-name methods must not reach any delegate", invocations.isEmpty());
    }

    /**
     * An {@link AsyncApplicationListener}-annotated listener is registered with the asynchronous multicaster
     * only; an unannotated one goes to the synchronous multicaster only. That routing is the reason this class
     * exists at all, so it is asserted here to keep the two removal paths meaningful.
     */
    @Test
    public void addApplicationListenerRoutesByAnnotation()
    {
        AsyncListener asyncListener = new AsyncListener();
        SyncListener syncListener = new SyncListener();

        distributiveEventMulticaster.addApplicationListener(asyncListener);
        distributiveEventMulticaster.addApplicationListener(syncListener);

        assertEquals(2, invocations.size());
        assertEquals(ASYNC + ":addApplicationListener", invocations.get(0));
        assertEquals(SYNC + ":addApplicationListener", invocations.get(1));
        assertSame(asyncListener, asyncMulticaster.getAddedListener());
        assertSame(syncListener, syncMulticaster.getAddedListener());
    }

    /**
     * Bulk removal reverses the pair order relative to the single-listener paths - synchronous first. Asserted
     * verbatim rather than normalised, because the whole point of these tests is that the delegation shape of
     * this class is preserved exactly as the Java 8 base commit had it.
     */
    @Test
    public void removeAllListenersDelegatesSyncThenAsync()
    {
        distributiveEventMulticaster.removeAllListeners();

        assertEquals(2, invocations.size());
        assertEquals(SYNC + ":removeAllListeners", invocations.get(0));
        assertEquals(ASYNC + ":removeAllListeners", invocations.get(1));
    }

    /**
     * Both publication overloads fan the event out to the synchronous multicaster first and then the
     * asynchronous one, passing the caller's event - and, for the typed overload, the caller's
     * {@link ResolvableType} - straight through.
     */
    @Test
    public void multicastEventDelegatesSyncThenAsync()
    {
        ApplicationEvent event = new ApplicationEvent(this)
        {
        };

        distributiveEventMulticaster.multicastEvent(event);

        assertEquals(2, invocations.size());
        assertEquals(SYNC + ":multicastEvent", invocations.get(0));
        assertEquals(ASYNC + ":multicastEvent", invocations.get(1));
        assertSame(event, syncMulticaster.getMulticastEvent());
        assertSame(event, asyncMulticaster.getMulticastEvent());
    }

    @Test
    public void multicastEventWithResolvableTypeDelegatesSyncThenAsync()
    {
        ApplicationEvent event = new ApplicationEvent(this)
        {
        };
        ResolvableType resolvableType = ResolvableType.forClass(ApplicationEvent.class);

        distributiveEventMulticaster.multicastEvent(event, resolvableType);

        assertEquals(2, invocations.size());
        assertEquals(SYNC + ":multicastEvent(ResolvableType)", invocations.get(0));
        assertEquals(ASYNC + ":multicastEvent(ResolvableType)", invocations.get(1));
        assertSame(resolvableType, syncMulticaster.getMulticastEventType());
        assertSame(resolvableType, asyncMulticaster.getMulticastEventType());
    }

    @AsyncApplicationListener
    private static class AsyncListener implements ApplicationListener<ApplicationEvent>
    {
        @Override
        public void onApplicationEvent(ApplicationEvent event)
        {
            // nothing to do: routing by annotation is what is under test, not the listener body
        }
    }

    private static class SyncListener implements ApplicationListener<ApplicationEvent>
    {
        @Override
        public void onApplicationEvent(ApplicationEvent event)
        {
            // nothing to do: routing by annotation is what is under test, not the listener body
        }
    }

    /**
     * Recording test double for a wrapped multicaster. Every call appends "&lt;name&gt;:&lt;method&gt;" to the
     * invocation log shared by both doubles, which is what makes cross-delegate ordering assertable, and the
     * arguments of the calls the tests reason about are retained so identity - not just equality - can be
     * checked.
     */
    private static class RecordingEventMulticaster implements ApplicationEventMulticaster
    {
        private final String name;
        private final List<String> invocations;

        private ApplicationListener<?> addedListener;
        private Predicate<ApplicationListener<?>> removedListenerPredicate;
        private int removedBeanPredicateCount;
        private ApplicationEvent multicastEvent;
        private ResolvableType multicastEventType;

        RecordingEventMulticaster(String name, List<String> invocations)
        {
            this.name = name;
            this.invocations = invocations;
        }

        @Override
        public void addApplicationListener(ApplicationListener<?> listener)
        {
            invocations.add(name + ":addApplicationListener");
            addedListener = listener;
        }

        @Override
        public void addApplicationListenerBean(String listenerBeanName)
        {
            invocations.add(name + ":addApplicationListenerBean");
        }

        @Override
        public void removeApplicationListener(ApplicationListener<?> listener)
        {
            invocations.add(name + ":removeApplicationListener");
        }

        @Override
        public void removeApplicationListenerBean(String listenerBeanName)
        {
            invocations.add(name + ":removeApplicationListenerBean");
        }

        @Override
        public void removeApplicationListeners(Predicate<ApplicationListener<?>> predicate)
        {
            invocations.add(name + ":removeApplicationListeners");
            removedListenerPredicate = predicate;
        }

        @Override
        public void removeApplicationListenerBeans(Predicate<String> predicate)
        {
            invocations.add(name + ":removeApplicationListenerBeans");
            removedBeanPredicateCount++;
        }

        @Override
        public void removeAllListeners()
        {
            invocations.add(name + ":removeAllListeners");
        }

        @Override
        public void multicastEvent(ApplicationEvent event)
        {
            invocations.add(name + ":multicastEvent");
            multicastEvent = event;
        }

        @Override
        public void multicastEvent(ApplicationEvent event, ResolvableType eventType)
        {
            invocations.add(name + ":multicastEvent(ResolvableType)");
            multicastEvent = event;
            multicastEventType = eventType;
        }

        ApplicationListener<?> getAddedListener()
        {
            return addedListener;
        }

        Predicate<ApplicationListener<?>> getRemovedListenerPredicate()
        {
            return removedListenerPredicate;
        }

        int getRemovedBeanPredicateCount()
        {
            return removedBeanPredicateCount;
        }

        ApplicationEvent getMulticastEvent()
        {
            return multicastEvent;
        }

        ResolvableType getMulticastEventType()
        {
            return multicastEventType;
        }
    }
}
