import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { after, before, beforeEach, test } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';

const projectId = 'eventease-4ad4c';
let testEnv;

before(async () => {
  const rules = await readFile(
    new URL('../../firestore.rules', import.meta.url),
    'utf8',
  );
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: { rules },
  });
});

after(async () => {
  await testEnv?.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await Promise.all([
      setDoc(doc(db, 'users', 'organizer'), { role: 'organizer' }),
      setDoc(doc(db, 'users', 'other-organizer'), { role: 'organizer' }),
      setDoc(doc(db, 'users', 'attendee'), { role: 'attendee' }),
    ]);
  });
});

function eventData(ownerUid, isPublished = false) {
  return {
    title: 'Test Event',
    description: 'Rules test event',
    category: 'Technology',
    date: 'Dec 15, 2026',
    time: '10:00 AM - 04:00 PM',
    location: 'Test venue',
    isVirtual: false,
    totalCapacity: 300,
    registeredCount: 0,
    checkedInCount: 0,
    ticketPrice: 0,
    bannerImageUrl: '',
    status: 'Upcoming',
    ownerUid,
    isPublished,
  };
}

test('organizers can preflight and create an unpublished event; attendees cannot', async () => {
  const organizerDb = testEnv.authenticatedContext('organizer').firestore();
  const attendeeDb = testEnv.authenticatedContext('attendee').firestore();
  const eventRef = doc(organizerDb, 'events', 'event-organizer');

  assert.equal((await assertSucceeds(getDoc(eventRef))).exists(), false);
  await assertSucceeds(setDoc(eventRef, eventData('organizer')));
  await assertFails(
    setDoc(
      doc(attendeeDb, 'events', 'event-attendee'),
      eventData('attendee'),
    ),
  );
});

test('only the owning organizer can publish or unpublish an event', async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'events', 'owned'),
      eventData('organizer'),
    );
  });

  const ownerDb = testEnv.authenticatedContext('organizer').firestore();
  const otherDb = testEnv.authenticatedContext('other-organizer').firestore();
  const ownerEvent = doc(ownerDb, 'events', 'owned');

  await assertSucceeds(updateDoc(ownerEvent, { isPublished: true }));
  await assertFails(
    updateDoc(doc(otherDb, 'events', 'owned'), { isPublished: false }),
  );
  await assertSucceeds(updateDoc(ownerEvent, { isPublished: false }));
});

test('organizers can preflight and manage only child records for their events', async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'events', 'owned'),
      eventData('organizer'),
    );
  });

  const organizerDb = testEnv.authenticatedContext('organizer').firestore();
  const attendeeDb = testEnv.authenticatedContext('attendee').firestore();
  const children = [
    {
      collectionName: 'attendees',
      id: 'attendee-1',
      data: {
        ownerUid: 'organizer',
        eventId: 'owned',
        name: 'Event attendee',
        email: 'guest@example.test',
        phone: '',
        ticketType: 'General',
        registeredDate: 'Today',
        isCheckedIn: false,
        checkInTime: null,
      },
    },
    {
      collectionName: 'schedules',
      id: 'schedule-1',
      data: {
        ownerUid: 'organizer',
        eventId: 'owned',
        time: '10:00 AM',
        title: 'Opening',
        speakerName: '',
        roomOrTrack: 'Main Hall',
        tag: 'General',
      },
    },
    {
      collectionName: 'announcements',
      id: 'announcement-1',
      data: {
        ownerUid: 'organizer',
        eventId: 'owned',
        title: 'Welcome',
        message: 'Welcome to the event.',
        timestamp: 'Just now',
        priority: 'Normal',
        sentTo: 'All Attendees',
      },
    },
  ];

  for (const child of children) {
    const childRef = doc(
      organizerDb,
      child.collectionName,
      child.id,
    );
    assert.equal((await assertSucceeds(getDoc(childRef))).exists(), false);
    await assertSucceeds(setDoc(childRef, child.data));
    await assertSucceeds(
      getDocs(
        query(
          collection(organizerDb, child.collectionName),
          where('ownerUid', '==', 'organizer'),
        ),
      ),
    );
    await assertFails(
      getDoc(doc(attendeeDb, child.collectionName, child.id)),
    );
  }
});

test('attendees can register once for published events, but cannot write as organizers', async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'events', 'published'),
      eventData('organizer', true),
    );
  });

  const attendeeDb = testEnv.authenticatedContext('attendee').firestore();
  const registration = doc(
    attendeeDb,
    'event_registrations',
    'published_attendee',
  );
  const registrationData = {
    eventId: 'published',
    organizerUid: 'organizer',
    attendeeUid: 'attendee',
    registeredAt: serverTimestamp(),
  };

  assert.equal((await assertSucceeds(getDoc(registration))).exists(), false);
  await assertSucceeds(setDoc(registration, registrationData));
  await assertFails(setDoc(registration, registrationData));

  const organizerDb = testEnv.authenticatedContext('organizer').firestore();
  await assertFails(
    setDoc(
      doc(organizerDb, 'event_registrations', 'published_organizer'),
      {
        ...registrationData,
        attendeeUid: 'organizer',
      },
    ),
  );
});

test('collection queries must prove owner or publication scope', async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await Promise.all([
      setDoc(
        doc(db, 'events', 'organizer-published'),
        eventData('organizer', true),
      ),
      setDoc(
        doc(db, 'events', 'organizer-draft'),
        eventData('organizer'),
      ),
      setDoc(
        doc(db, 'events', 'other-published'),
        eventData('other-organizer', true),
      ),
    ]);
  });

  const attendeeDb = testEnv.authenticatedContext('attendee').firestore();
  const publishedEvents = query(
    collection(attendeeDb, 'events'),
    where('isPublished', '==', true),
  );
  assert.equal((await assertSucceeds(getDocs(publishedEvents))).size, 2);
  await assertFails(getDocs(collection(attendeeDb, 'events')));

  const organizerDb = testEnv.authenticatedContext('organizer').firestore();
  const ownEvents = query(
    collection(organizerDb, 'events'),
    where('ownerUid', '==', 'organizer'),
  );
  assert.equal((await assertSucceeds(getDocs(ownEvents))).size, 2);
});

test('users cannot create an organizer profile or change their own role', async () => {
  const newAttendeeDb = testEnv.authenticatedContext('new-attendee', {
    email: 'attendee@example.test',
  }).firestore();
  const profile = (uid, role, email) => ({
    uid,
    displayName: 'Attendee',
    email,
    role,
    onboardingCompleted: true,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });

  await assertSucceeds(
    setDoc(
      doc(newAttendeeDb, 'users', 'new-attendee'),
      profile('new-attendee', 'attendee', 'attendee@example.test'),
    ),
  );
  const newOrganizerDb = testEnv.authenticatedContext('new-organizer', {
    email: 'organizer@example.test',
  }).firestore();
  await assertFails(
    setDoc(
      doc(newOrganizerDb, 'users', 'new-organizer'),
      profile('new-organizer', 'organizer', 'organizer@example.test'),
    ),
  );

  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'users', 'attendee'), {
      uid: 'attendee',
      displayName: 'Attendee',
      email: 'attendee@example.test',
      role: 'attendee',
      onboardingCompleted: true,
      createdAt: new Date(),
      updatedAt: new Date(),
    });
  });
  const attendeeDb = testEnv.authenticatedContext('attendee', {
    email: 'attendee@example.test',
  }).firestore();
  await assertSucceeds(
    updateDoc(doc(attendeeDb, 'users', 'attendee'), {
      displayName: 'Updated attendee',
      updatedAt: serverTimestamp(),
    }),
  );
  await assertFails(
    updateDoc(doc(attendeeDb, 'users', 'attendee'), {
      role: 'organizer',
      updatedAt: serverTimestamp(),
    }),
  );
  await assertFails(getDoc(doc(attendeeDb, 'users', 'other-organizer')));
});
