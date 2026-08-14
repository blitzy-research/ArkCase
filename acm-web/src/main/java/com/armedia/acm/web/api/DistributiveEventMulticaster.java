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

import org.springframework.context.ApplicationEvent;
import org.springframework.context.ApplicationListener;
import org.springframework.context.event.ApplicationEventMulticaster;
import org.springframework.core.ResolvableType;

import java.util.function.Predicate;

/**
 * {@link ApplicationEventMulticaster} implementation for publishing events to synchronous and asynchronous listeners.
 * <p>
 * Created by Bojan Milenkoski on 15.1.2016.
 */
public class DistributiveEventMulticaster implements ApplicationEventMulticaster
{

    private ApplicationEventMulticaster asyncEventMulticaster;
    private ApplicationEventMulticaster syncEventMulticaster;

    @Override
    public void addApplicationListener(ApplicationListener<?> listener)
    {
        if (listener.getClass().getAnnotation(AsyncApplicationListener.class) != null)
        {
            asyncEventMulticaster.addApplicationListener(listener);
        }
        else
        {
            syncEventMulticaster.addApplicationListener(listener);
        }
    }

    /**
     * No-op by design. A bean name on its own cannot be routed, because the {@link AsyncApplicationListener}
     * annotation that decides between the synchronous and the asynchronous delegate is read from the listener's own
     * class in {@link #addApplicationListener(ApplicationListener)}, and singleton listeners already arrive through
     * that instance path. Discarding the name is therefore what makes this wrapper hold no bean-name state at all,
     * which is why the two remove-by-name methods below have nothing to act on.
     */
    @Override
    public void addApplicationListenerBean(String listenerBeanName)
    {
    }

    @Override
    public void removeApplicationListener(ApplicationListener<?> listener)
    {
        asyncEventMulticaster.removeApplicationListener(listener);
        syncEventMulticaster.removeApplicationListener(listener);
    }

    /**
     * No-op by design: nothing is registered by bean name, so there is nothing to remove by bean name.
     */
    @Override
    public void removeApplicationListenerBean(String listenerBeanName)
    {
    }

    @Override
    public void removeApplicationListeners(Predicate<ApplicationListener<?>> predicate)
    {
        asyncEventMulticaster.removeApplicationListeners(predicate);
        syncEventMulticaster.removeApplicationListeners(predicate);
    }

    /**
     * No-op by design, for the same reason as {@link #removeApplicationListenerBean(String)}: this multicaster keeps
     * no bean names for a predicate to match.
     */
    @Override
    public void removeApplicationListenerBeans(Predicate<String> predicate)
    {
    }

    @Override
    public void removeAllListeners()
    {
        syncEventMulticaster.removeAllListeners();
        asyncEventMulticaster.removeAllListeners();
    }

    @Override
    public void multicastEvent(ApplicationEvent event)
    {
        syncEventMulticaster.multicastEvent(event);
        asyncEventMulticaster.multicastEvent(event);
    }

    @Override
    public void multicastEvent(ApplicationEvent event, ResolvableType resolvableType)
    {
        syncEventMulticaster.multicastEvent(event, resolvableType);
        asyncEventMulticaster.multicastEvent(event, resolvableType);
    }

    public void setAsyncEventMulticaster(ApplicationEventMulticaster asyncEventMulticaster)
    {
        this.asyncEventMulticaster = asyncEventMulticaster;
    }

    public void setSyncEventMulticaster(ApplicationEventMulticaster syncEventMulticaster)
    {
        this.syncEventMulticaster = syncEventMulticaster;
    }
}
