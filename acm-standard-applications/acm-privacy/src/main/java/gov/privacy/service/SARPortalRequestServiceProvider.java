package gov.privacy.service;

/*-
 * #%L
 * ACM Privacy: Subject Access Request
 * %%
 * Copyright (C) 2014 - 2019 ArkCase LLC
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

import com.armedia.acm.core.exceptions.AcmCreateObjectFailedException;
import com.armedia.acm.core.exceptions.AcmObjectNotFoundException;
import com.armedia.acm.core.exceptions.AcmUserActionFailedException;
import com.armedia.acm.portalgateway.service.PortalRequestServiceException;
import com.armedia.acm.portalgateway.service.PortalRequestServiceProvider;
import com.armedia.acm.portalgateway.web.api.PortalRequest;
import com.armedia.acm.portalgateway.web.api.PortalResponse;
import com.armedia.acm.services.pipeline.exception.PipelineProcessException;
import com.fasterxml.jackson.core.JsonParser;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.BeanDescription;
import com.fasterxml.jackson.databind.DeserializationConfig;
import com.fasterxml.jackson.databind.DeserializationContext;
import com.fasterxml.jackson.databind.JavaType;
import com.fasterxml.jackson.databind.JsonDeserializer;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.deser.Deserializers;
import com.fasterxml.jackson.databind.module.SimpleModule;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import javax.persistence.NoResultException;
import javax.persistence.NonUniqueResultException;

import java.io.IOException;
import java.util.List;
import java.util.stream.Collectors;

import gov.privacy.model.PortalSARInquiry;
import gov.privacy.model.PortalSARStatus;
import gov.privacy.model.PortalSubjectAccessRequest;

/**
 * @author Vladimir Cherepnalkovski <vladimir.cherepnalkovski@armedia.com> on Jun, 2020
 *
 */
public class SARPortalRequestServiceProvider implements PortalRequestServiceProvider
{
    private transient final Logger log = LogManager.getLogger(getClass());

    private PortalCreateRequestService createRequestService;

    private PortalRequestService portalRequestService;

    private PortalCreateInquiryService portalCreateInquiryService;

    /*
     * (non-Javadoc)
     * @see com.armedia.acm.portalgateway.service.PortalRequestServiceProvider#providesServiceForRequestType()
     */
    @Override
    public String providesServiceForRequestType()
    {
        return PortalSubjectAccessRequest.class.getName();
    }

    /*
     * (non-Javadoc)
     * @see com.armedia.acm.portalgateway.service.PortalRequestServiceProvider#submitRequest(java.lang.String,
     * com.armedia.acm.portalgateway.web.api.PortalRequest)
     */
    @Override
    public PortalResponse submitRequest(String portalId, String portalUserId, PortalRequest request) throws PortalRequestServiceException
    {
        log.debug("Submitting request from portal with [{}] ID for portal user with [{}] ID of [{}] type.", portalId, portalUserId,
                request.getRequestType());
        String rawRequestContent = request.getRawRequestContent();
        ObjectMapper mapper = portalRequestMapper();
        try
        {
            PortalSubjectAccessRequest sar = mapper.readValue(rawRequestContent, PortalSubjectAccessRequest.class);
            sar.setUserId(portalUserId);
            createRequestService.createSAR(sar);
            return new PortalResponse();
        }
        catch (IOException e)
        {
            log.warn("Error deserializing raw request from user with ID [{}] from portal with ID [{}].", portalUserId, portalId);
            throw new PortalRequestServiceException(
                    String.format("Error deserializing raw request from user with ID [%s] from portal with ID [%s].", portalUserId,
                            portalId),
                    e, SUBMIT_REQUEST_METHOD_DESERIALIZE);
        }
        catch (AcmCreateObjectFailedException | AcmUserActionFailedException | PipelineProcessException e)
        {
            log.warn("Error creating request for raw request from user with ID [{}] from portal with ID [{}].", portalUserId, portalId);
            throw new PortalRequestServiceException(
                    String.format("Error creating request for raw request from user with ID [%s] from portal with ID [%s].",
                            portalUserId, portalId),
                    e, SUBMIT_REQUEST_METHOD_CREATE_REQUEST);
        }
    }

    /**
     * Builds the mapper that reads a portal request, preserving the Java 8 treatment of java.time values.
     * <p>
     * The request is deserialized by a plain {@link ObjectMapper} with no java.time module registered, exactly as it was
     * before this platform moved to Java 17, so the accepted request shape is unchanged: a request that omits
     * <code>signatureDate</code> and the subject's and requester's <code>dateOfBirth</code>, or sends them as
     * <code>null</code>, is accepted, and one that sends a value for any of them is rejected as a deserialization
     * failure. Registering a java.time module here would instead start accepting ISO-8601 date strings, which would widen
     * the published request contract.
     * <p>
     * What the module below changes is only <em>how</em> such a value is rejected. Without it, Jackson tries to bind
     * java.time values reflectively, and on Java 17 that reflection is refused by the platform itself with an
     * {@link java.lang.reflect.InaccessibleObjectException} - an unchecked exception which escapes the
     * <code>catch (IOException)</code> below and surfaces as a bare server error, and which is raised while the
     * deserializer is being built, so it strikes even requests that carry no date at all. The module keeps java.time out
     * of reflective binding altogether: an absent or null value stays null, and a present value raises the same
     * {@link com.fasterxml.jackson.databind.JsonMappingException} that Java 8 raised, which this method's caller already
     * translates into a {@link PortalRequestServiceException}. The alternative - opening <code>java.base/java.time</code>
     * in the production launch configuration - is deliberately not used.
     *
     * @return a mapper for portal request content; never <code>null</code>.
     */
    private static ObjectMapper portalRequestMapper()
    {
        return new ObjectMapper().registerModule(new UnsupportedJavaTimeModule());
    }

    /**
     * Jackson module that refuses java.time values instead of binding them reflectively.
     */
    private static class UnsupportedJavaTimeModule extends SimpleModule
    {
        private static final long serialVersionUID = 1L;

        @Override
        public void setupModule(SetupContext context)
        {
            super.setupModule(context);
            context.addDeserializers(new Deserializers.Base()
            {
                @Override
                public JsonDeserializer<?> findBeanDeserializer(JavaType type, DeserializationConfig config,
                        BeanDescription beanDescription)
                {
                    // A custom deserializer is consulted before Jackson introspects the type, so no java.time class is
                    // ever reflected over. Everything outside java.time is left to Jackson's own defaults.
                    return type.getRawClass().getName().startsWith("java.time.") ? new UnsupportedValueDeserializer(type) : null;
                }
            });
        }
    }

    /**
     * Reports a value of an unsupported type as a mapping failure. Jackson resolves a JSON null through
     * {@link JsonDeserializer#getNullValue(DeserializationContext)} without consulting this method, so only a value that
     * is actually present is rejected - which is precisely the Java 8 behaviour being preserved. The value itself is
     * never quoted in the message, because portal request content carries personal data.
     */
    private static class UnsupportedValueDeserializer extends JsonDeserializer<Object>
    {
        private final JavaType type;

        UnsupportedValueDeserializer(JavaType type)
        {
            this.type = type;
        }

        @Override
        public Object deserialize(JsonParser parser, DeserializationContext context) throws IOException
        {
            return context.reportBadDefinition(type, String.format(
                    "Cannot construct instance of `%s` (no Creators, like default construct, exist)", type.getRawClass().getName()));
        }
    }

    /*
     * (non-Javadoc)
     * @see com.armedia.acm.portalgateway.service.PortalRequestServiceProvider#listRequests(java.lang.String,
     * java.lang.String)
     */
    @Override
    public List<PortalResponse> listRequests(String portalId, String portalUserId) throws PortalRequestServiceException
    {
        try
        {
            List<PortalSARStatus> externalRequests = portalRequestService.getExternalRequests(portalUserId);
            return externalRequests.stream().map(this::mapRequestStatus).collect(Collectors.toList());
        }
        catch (AcmObjectNotFoundException e)
        {
            log.warn("Error fetching requests for user with ID [{}] from portal with ID [{}].", portalUserId, portalId);
            throw new PortalRequestServiceException(
                    String.format("Error fetching requests for user with ID [%s] from portal with ID [%s].", portalUserId, portalId), e,
                    LIST_REQUESTS_METHOD_RETRIEVE);
        }
        catch (ResponseMappingException e)
        {
            log.warn("Error serializing raw response due to [{}] from user with ID [{}] from portal with ID [{}].", e.getCause(),
                    portalUserId, portalId);
            throw new PortalRequestServiceException(String.format(
                    "Error serializing raw response due to [%s] from user with ID [%s] from portal with ID [%s].", e.getCause(),
                    portalUserId, portalId), e, LIST_REQUESTS_METHOD_SERIALIZE);
        }

    }

    /*
     * (non-Javadoc)
     * @see com.armedia.acm.portalgateway.service.PortalRequestServiceProvider#getRequestStatus(java.lang.String,
     * java.lang.String, java.lang.String)
     */
    @Override
    public PortalResponse getRequestStatus(String portalId, String portalUserId, String requestId) throws PortalRequestServiceException
    {
        try
        {
            PortalSARStatus mapRequestStatus = portalRequestService.getExternalRequest(portalUserId, requestId);
            // TODO: this should be configurable
            // if ("Approved".equals(mapRequestStatus.getRequestStatus()))
            // {
            // // TODO: if a request processing was finished, we should return the result instead as part of
            // // PortalResponse#rawResponse
            // }
            return mapRequestStatus(mapRequestStatus);
        }
        catch (NoResultException | NonUniqueResultException e)
        {
            log.warn("Error fetching request with ID [{}] for user with ID [{}] from portal with ID [{}].", requestId, portalUserId,
                    portalId);
            throw new PortalRequestServiceException(String.format(
                    "Error fetching request with ID [%s] for user with ID [%s] from portal with ID [%s].", requestId, portalUserId,
                    portalId), e, GET_REQUEST_STATUS_METHOD_RETRIEVE);
        }
        catch (ResponseMappingException e)
        {
            log.warn("Error serializing raw response for request with ID [{}] due to [{}] from user with ID [{}] from portal with ID [{}].",
                    requestId, e.getCause(), portalUserId, portalId);
            throw new PortalRequestServiceException(String.format(
                    "Error serializing raw response for request with ID [%s] due to [%s}] from user with ID [%s] from portal with ID [%s].",
                    requestId, e.getCause(), portalUserId, portalId), e, GET_REQUEST_STATUS_METHOD_SERIALIZE);
        }
    }

    private PortalResponse mapRequestStatus(PortalSARStatus status)
    {
        try
        {
            ObjectMapper mapper = new ObjectMapper();
            PortalResponse rs = new PortalResponse();
            rs.setResponseType(PortalSARStatus.class.getName());
            rs.setRawResponse(mapper.writeValueAsString(status));
            return rs;
        }
        catch (JsonProcessingException e)
        {
            throw new ResponseMappingException(e);
        }
    }


    /*
     * (non-Javadoc)
     * @see com.armedia.acm.portalgateway.service.PortalRequestServiceProvider#submitInquiry(com.armedia.acm.portalgateway.web.api.PortalRequest)
     */
    @Override
    public void submitInquiry(PortalRequest request) throws PortalRequestServiceException
    {
        log.debug("Submitting request from portal with [{}] ID for portal user with [{}] ID of [{}] type.",
                request.getRequestType());
        String rawRequestContent = request.getRawRequestContent();
        ObjectMapper mapper = new ObjectMapper();
        try
        {
            PortalSARInquiry sarInquiry = mapper.readValue(rawRequestContent, PortalSARInquiry.class);
            portalCreateInquiryService.createSARInquiry(sarInquiry);
        }
        catch (IOException e)
        {
            log.warn("Error deserializing raw request [{}] from user with ID [{}] from portal with ID [{}].", rawRequestContent);
            throw new PortalRequestServiceException(String.format(
                    "Error deserializing raw request [%s] from user with ID [%s] from portal with ID [%s].", rawRequestContent), e, SUBMIT_REQUEST_METHOD_DESERIALIZE);
        }

    }

    /**
     * @param createRequestService
     *            the createRequestService to set
     */
    public void setCreateRequestService(PortalCreateRequestService createRequestService)
    {
        this.createRequestService = createRequestService;
    }

    /**
     * @param portalRequestService
     *            the portalRequestService to set
     */
    public void setPortalRequestService(PortalRequestService portalRequestService)
    {
        this.portalRequestService = portalRequestService;
    }

    public PortalCreateInquiryService getPortalCreateInquiryService()
    {
        return portalCreateInquiryService;
    }

    public void setPortalCreateInquiryService(PortalCreateInquiryService portalCreateInquiryService)
    {
        this.portalCreateInquiryService = portalCreateInquiryService;
    }
}
