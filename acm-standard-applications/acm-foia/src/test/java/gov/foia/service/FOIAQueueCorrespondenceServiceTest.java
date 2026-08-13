package gov.foia.service;

/*-
 * #%L
 * ACM Standard Application: Freedom of Information Act
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

import static org.easymock.EasyMock.capture;
import static org.easymock.EasyMock.eq;
import static org.easymock.EasyMock.expect;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertSame;

import com.armedia.acm.plugins.addressable.model.ContactMethod;
import com.armedia.acm.plugins.ecm.model.AcmContainer;
import com.armedia.acm.plugins.ecm.model.AcmFolder;
import com.armedia.acm.plugins.ecm.model.EcmFileVersion;
import com.armedia.acm.plugins.person.model.Person;
import com.armedia.acm.plugins.person.model.PersonAssociation;
import com.armedia.acm.services.notification.model.Notification;
import com.armedia.acm.services.notification.service.NotificationBuilder;
import com.armedia.acm.services.notification.service.NotificationFormatter;
import com.armedia.acm.services.notification.service.NotificationService;
import com.armedia.acm.services.templateconfiguration.model.Template;
import com.armedia.acm.services.templateconfiguration.service.CorrespondenceTemplateManager;
import com.armedia.acm.services.users.dao.UserDao;

import org.easymock.Capture;
import org.easymock.EasyMockSupport;
import org.junit.Before;
import org.junit.Test;

import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.Map;

import gov.foia.dao.FOIARequestDao;
import gov.foia.model.FOIAConstants;
import gov.foia.model.FOIADocumentDescriptor;
import gov.foia.model.FOIAFile;
import gov.foia.model.FOIARequest;

/**
 * Unit tests for {@link FOIAQueueCorrespondenceService#handleRequestReceivedAcknowledgementLetter(Long)}.
 * <p>
 * The subject of these tests is the requestor-address guard on the notification branch of that method. The guard
 * is {@code StringUtils.isNotEmpty}, from commons-lang3, and it replaced a FastInfoset emptiness check that the
 * Java 17 migration had to remove. {@code isNotEmpty} is NOT {@code isNotBlank}: a whitespace-only address is
 * non-empty and therefore still notified, which is exactly the behaviour of the check it replaced and is pinned
 * here so a future "improvement" to {@code isNotBlank} cannot slip in unnoticed.
 * <p>
 * The four address shapes are covered: a real address, {@code null}, the empty string and whitespace-only - plus
 * the shape that produces the empty string most often in practice, a requestor with no contact methods at all.
 * In the two cases that must not notify, {@link NotificationService} is a mock with NO expectations, so any
 * attempt to build or save a notification fails the test outright rather than passing silently. That matters
 * here because the method body is wrapped in {@code catch (Exception)}: EasyMock signals an unexpected call with
 * an {@link AssertionError}, which is not an {@link Exception} and therefore is not swallowed by that handler.
 * <p>
 * The letter generation that precedes the guard is driven with mocks so the guard is reached in a realistic
 * state; {@code verifyAll} confirms the generated document version really did travel into the notification, which
 * is what proves the positive branch ran to completion rather than aborting into the catch block.
 */
public class FOIAQueueCorrespondenceServiceTest extends EasyMockSupport
{
    private static final Long REQUEST_ID = 101L;
    private static final String OBJECT_TYPE = "CASE_FILE";
    private static final String REQUEST_TYPE = "New Request";
    private static final String CASE_NUMBER = "20260813-101";
    private static final String REQUEST_TITLE = "Records request";
    private static final String EMAIL_CONTACT_TYPE = "email";
    private static final String EMAIL_ADDRESS = "requestor@arkcase.org";
    private static final String EMAIL_SUBJECT = "Your requested document is attached";
    private static final String TARGET_FOLDER_ID = "workspace://SpacesStore/ack-folder";
    private static final String FILENAME_FORMAT = "ACK_%s.pdf";
    private static final String TEMPLATE_NAME = "requestDocumentAttached.html";

    private FOIAQueueCorrespondenceService queueCorrespondenceService;

    private FOIARequestDao requestDao;
    private FOIADocumentGeneratorService documentGeneratorService;
    private DocumentGenerator documentGenerator;
    private NotificationService notificationService;
    private CorrespondenceTemplateManager templateManager;
    private UserDao userDao;

    private FOIARequest request;
    private AcmContainer container;
    private AcmFolder folder;
    private PersonAssociation originator;
    private Person requestor;
    private ContactMethod contactMethod;

    private FOIADocumentDescriptor documentDescriptor;
    private FOIAFile letter;
    private EcmFileVersion letterVersion;
    private Map<String, String> substitutions;

    @Before
    public void setUp()
    {
        requestDao = createMock(FOIARequestDao.class);
        documentGeneratorService = createMock(FOIADocumentGeneratorService.class);
        documentGenerator = createMock(DocumentGenerator.class);
        notificationService = createMock(NotificationService.class);
        templateManager = createMock(CorrespondenceTemplateManager.class);
        userDao = createMock(UserDao.class);

        request = createMock(FOIARequest.class);
        container = createMock(AcmContainer.class);
        folder = createMock(AcmFolder.class);
        originator = createMock(PersonAssociation.class);
        requestor = createMock(Person.class);
        contactMethod = createMock(ContactMethod.class);

        queueCorrespondenceService = new FOIAQueueCorrespondenceService();
        queueCorrespondenceService.setRequestDao(requestDao);
        queueCorrespondenceService.setDocumentGeneratorService(documentGeneratorService);
        queueCorrespondenceService.setDocumentGenerator(documentGenerator);
        queueCorrespondenceService.setNotificationService(notificationService);
        queueCorrespondenceService.setTemplateManager(templateManager);
        queueCorrespondenceService.setUserDao(userDao);

        documentDescriptor = new FOIADocumentDescriptor();
        documentDescriptor.setReqAck(FOIAConstants.RECEIVE_ACK);
        documentDescriptor.setFilenameFormat(FILENAME_FORMAT);

        letterVersion = new EcmFileVersion();
        letterVersion.setVersionTag("1.0");
        letter = new FOIAFile();
        letter.setVersions(Arrays.asList(letterVersion));

        substitutions = new HashMap<>();
    }

    /**
     * A requestor with a real email address is notified: the notification carries that address, the freshly
     * generated document version and the template's subject, and it is handed to the notification service to be
     * saved.
     */
    @Test
    public void nonEmptyEmailAddressIsNotified()
    {
        expectLetterGeneration();
        expectRequestorEmailAddress(EMAIL_ADDRESS);

        Template template = new Template();
        template.setEmailSubject(EMAIL_SUBJECT);
        expect(templateManager.findTemplate(TEMPLATE_NAME)).andReturn(template);

        expect(notificationService.getNotificationBuilder()).andReturn(notificationBuilder());
        Capture<Notification> savedNotification = Capture.newInstance();
        expect(notificationService.saveNotification(capture(savedNotification))).andReturn(new Notification());

        replayAll();

        queueCorrespondenceService.handleRequestReceivedAcknowledgementLetter(REQUEST_ID);

        verifyAll();

        Notification notification = savedNotification.getValue();
        assertEquals(EMAIL_ADDRESS, notification.getEmailAddresses());
        assertEquals(EMAIL_SUBJECT, notification.getSubject());
        assertEquals(OBJECT_TYPE, notification.getParentType());
        assertEquals(REQUEST_ID, notification.getParentId());
        assertEquals(CASE_NUMBER, notification.getParentName());
        assertEquals(REQUEST_TITLE, notification.getParentTitle());
        assertEquals("the generated letter's latest version must be attached", 1, notification.getFiles().size());
        assertSame(letterVersion, notification.getFiles().get(0));
    }

    /**
     * A missing template must not stop the notification - the subject simply stays empty. Kept alongside the
     * happy path because the template lookup sits inside the guarded branch, so it only runs when the address is
     * non-empty.
     */
    @Test
    public void nonEmptyEmailAddressIsNotifiedWithAnEmptySubjectWhenNoTemplateExists()
    {
        expectLetterGeneration();
        expectRequestorEmailAddress(EMAIL_ADDRESS);

        expect(templateManager.findTemplate(TEMPLATE_NAME)).andReturn(null);

        expect(notificationService.getNotificationBuilder()).andReturn(notificationBuilder());
        Capture<Notification> savedNotification = Capture.newInstance();
        expect(notificationService.saveNotification(capture(savedNotification))).andReturn(new Notification());

        replayAll();

        queueCorrespondenceService.handleRequestReceivedAcknowledgementLetter(REQUEST_ID);

        verifyAll();

        assertEquals(EMAIL_ADDRESS, savedNotification.getValue().getEmailAddresses());
        assertEquals("", savedNotification.getValue().getSubject());
    }

    /**
     * Whitespace is not emptiness. {@code isNotEmpty(" ")} is true, so a whitespace-only address is still
     * notified - the behaviour of the emptiness check this guard replaced, preserved deliberately rather than
     * "improved" to {@code isNotBlank}.
     */
    @Test
    public void whitespaceOnlyEmailAddressIsStillTreatedAsNonEmptyAndIsNotified()
    {
        expectLetterGeneration();
        expectRequestorEmailAddress("   ");

        Template template = new Template();
        template.setEmailSubject(EMAIL_SUBJECT);
        expect(templateManager.findTemplate(TEMPLATE_NAME)).andReturn(template);

        expect(notificationService.getNotificationBuilder()).andReturn(notificationBuilder());
        Capture<Notification> savedNotification = Capture.newInstance();
        expect(notificationService.saveNotification(capture(savedNotification))).andReturn(new Notification());

        replayAll();

        queueCorrespondenceService.handleRequestReceivedAcknowledgementLetter(REQUEST_ID);

        verifyAll();

        assertEquals("   ", savedNotification.getValue().getEmailAddresses());
    }

    /**
     * A null address - a contact method of type email whose value was never populated - must not notify. The
     * notification service mock has no expectations at all, so building or saving one would fail the test.
     */
    @Test
    public void nullEmailAddressIsNotNotified()
    {
        expectLetterGeneration();
        expectRequestorEmailAddress(null);

        replayAll();

        queueCorrespondenceService.handleRequestReceivedAcknowledgementLetter(REQUEST_ID);

        verifyAll();
    }

    /**
     * An empty address must not notify either.
     */
    @Test
    public void emptyEmailAddressIsNotNotified()
    {
        expectLetterGeneration();
        expectRequestorEmailAddress("");

        replayAll();

        queueCorrespondenceService.handleRequestReceivedAcknowledgementLetter(REQUEST_ID);

        verifyAll();
    }

    /**
     * The most common real-world source of an empty address: a requestor with no contact methods at all, for
     * which the address extraction yields the empty string. Must not notify.
     */
    @Test
    public void requestorWithoutContactMethodsIsNotNotified()
    {
        expectLetterGeneration();
        expect(request.getOriginator()).andReturn(originator);
        expect(originator.getPerson()).andReturn(requestor);
        expect(requestor.getContactMethods()).andReturn(Collections.emptyList());

        replayAll();

        queueCorrespondenceService.handleRequestReceivedAcknowledgementLetter(REQUEST_ID);

        verifyAll();
    }

    /**
     * Everything the method does before the address guard: look the request up, resolve the acknowledgement
     * descriptor, compute the target folder and the filename, and generate and upload the letter. The generated
     * filename is asserted through {@code eq(...)} on the generator call, so a change to either the descriptor
     * format or the folder resolution would fail these tests rather than pass unnoticed.
     */
    private void expectLetterGeneration()
    {
        expect(requestDao.find(REQUEST_ID)).andReturn(request);
        expect(documentGeneratorService.getDocumentDescriptor(request, FOIAConstants.RECEIVE_ACK))
                .andReturn(documentDescriptor);
        expect(documentGeneratorService.getReportSubstitutions(request)).andReturn(substitutions);

        expect(request.getId()).andReturn(REQUEST_ID).anyTimes();
        expect(request.getObjectType()).andReturn(OBJECT_TYPE).anyTimes();
        expect(request.getRequestType()).andReturn(REQUEST_TYPE).anyTimes();
        expect(request.getCaseNumber()).andReturn(CASE_NUMBER).anyTimes();
        expect(request.getTitle()).andReturn(REQUEST_TITLE).anyTimes();
        // no assignee, so the user lookup is skipped entirely and the notification is raised without a user
        expect(request.getAssigneeLdapId()).andReturn(null).anyTimes();

        expect(request.getContainer()).andReturn(container).anyTimes();
        expect(container.getAttachmentFolder()).andReturn(null).anyTimes();
        expect(container.getFolder()).andReturn(folder).anyTimes();
        expect(folder.getCmisFolderId()).andReturn(TARGET_FOLDER_ID).anyTimes();

        try
        {
            expect(documentGenerator.generateAndUpload(eq(documentDescriptor), eq(request), eq(TARGET_FOLDER_ID),
                    eq(String.format(FILENAME_FORMAT, REQUEST_ID)), eq(substitutions))).andReturn(letter);
        }
        catch (DocumentGeneratorException e)
        {
            throw new IllegalStateException("recording a mock expectation cannot fail", e);
        }
    }

    /**
     * Give the requestor a single email contact method carrying the supplied value.
     */
    private void expectRequestorEmailAddress(String emailAddress)
    {
        expect(request.getOriginator()).andReturn(originator);
        expect(originator.getPerson()).andReturn(requestor);
        expect(requestor.getContactMethods()).andReturn(Arrays.asList(contactMethod));
        expect(contactMethod.getType()).andReturn(EMAIL_CONTACT_TYPE);
        expect(contactMethod.getValue()).andReturn(emailAddress);
    }

    /**
     * A real {@link NotificationBuilder} rather than a mocked fluent chain, so the notification the service hands
     * over is assembled by production code and the assertions above are about real content. Only its title
     * formatter is stubbed, because formatting is a separate concern with its own collaborators.
     */
    private NotificationBuilder notificationBuilder()
    {
        NotificationBuilder notificationBuilder = new NotificationBuilder();
        notificationBuilder.setNotificationFormatter(createNiceMock(NotificationFormatter.class));
        return notificationBuilder;
    }
}
