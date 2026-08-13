<?php

/*
 * Copyright (C) 2026 pyarmak <pyarmak@gmail.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 * AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
 * OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

namespace OPNsense\Blocky\Api;

use OPNsense\Base\ApiMutableModelControllerBase;

/**
 * Settings and grid endpoints for the blocky model.
 */
class SettingsController extends ApiMutableModelControllerBase
{
    protected static $internalModelName = 'blocky';
    protected static $internalModelClass = '\OPNsense\Blocky\Blocky';

    public function searchUpstreamAction()
    {
        return $this->searchBase('upstreams.upstream');
    }

    public function getUpstreamAction($uuid = null)
    {
        return $this->getBase('upstream', 'upstreams.upstream', $uuid);
    }

    public function addUpstreamAction()
    {
        return $this->addBase('upstream', 'upstreams.upstream');
    }

    public function setUpstreamAction($uuid)
    {
        return $this->setBase('upstream', 'upstreams.upstream', $uuid);
    }

    public function delUpstreamAction($uuid)
    {
        return $this->delBase('upstreams.upstream', $uuid);
    }

    public function toggleUpstreamAction($uuid, $enabled = null)
    {
        return $this->toggleBase('upstreams.upstream', $uuid, $enabled);
    }

    public function searchDenylistAction()
    {
        return $this->searchBase('blocking.denylist');
    }

    public function getDenylistAction($uuid = null)
    {
        return $this->getBase('denylist', 'blocking.denylist', $uuid);
    }

    public function addDenylistAction()
    {
        return $this->addBase('denylist', 'blocking.denylist');
    }

    public function setDenylistAction($uuid)
    {
        return $this->setBase('denylist', 'blocking.denylist', $uuid);
    }

    public function delDenylistAction($uuid)
    {
        return $this->delBase('blocking.denylist', $uuid);
    }

    public function toggleDenylistAction($uuid, $enabled = null)
    {
        return $this->toggleBase('blocking.denylist', $uuid, $enabled);
    }

    public function searchAllowlistAction()
    {
        return $this->searchBase('blocking.allowlist');
    }

    public function getAllowlistAction($uuid = null)
    {
        return $this->getBase('allowlist', 'blocking.allowlist', $uuid);
    }

    public function addAllowlistAction()
    {
        return $this->addBase('allowlist', 'blocking.allowlist');
    }

    public function setAllowlistAction($uuid)
    {
        return $this->setBase('allowlist', 'blocking.allowlist', $uuid);
    }

    public function delAllowlistAction($uuid)
    {
        return $this->delBase('blocking.allowlist', $uuid);
    }

    public function toggleAllowlistAction($uuid, $enabled = null)
    {
        return $this->toggleBase('blocking.allowlist', $uuid, $enabled);
    }

    public function searchClientgroupAction()
    {
        return $this->searchBase('clientgroups.clientgroup');
    }

    public function getClientgroupAction($uuid = null)
    {
        return $this->getBase('clientgroup', 'clientgroups.clientgroup', $uuid);
    }

    public function addClientgroupAction()
    {
        return $this->addBase('clientgroup', 'clientgroups.clientgroup');
    }

    public function setClientgroupAction($uuid)
    {
        return $this->setBase('clientgroup', 'clientgroups.clientgroup', $uuid);
    }

    public function delClientgroupAction($uuid)
    {
        return $this->delBase('clientgroups.clientgroup', $uuid);
    }

    public function toggleClientgroupAction($uuid, $enabled = null)
    {
        return $this->toggleBase('clientgroups.clientgroup', $uuid, $enabled);
    }

    public function searchScheduleAction()
    {
        return $this->searchBase('schedules.schedule');
    }

    public function getScheduleAction($uuid = null)
    {
        return $this->getBase('schedule', 'schedules.schedule', $uuid);
    }

    public function addScheduleAction()
    {
        return $this->addBase('schedule', 'schedules.schedule');
    }

    public function setScheduleAction($uuid)
    {
        return $this->setBase('schedule', 'schedules.schedule', $uuid);
    }

    public function delScheduleAction($uuid)
    {
        return $this->delBase('schedules.schedule', $uuid);
    }

    public function toggleScheduleAction($uuid, $enabled = null)
    {
        return $this->toggleBase('schedules.schedule', $uuid, $enabled);
    }

    public function searchListscheduleAction()
    {
        return $this->searchBase('schedules.listschedule');
    }

    public function getListscheduleAction($uuid = null)
    {
        return $this->getBase('listschedule', 'schedules.listschedule', $uuid);
    }

    public function addListscheduleAction()
    {
        return $this->addBase('listschedule', 'schedules.listschedule');
    }

    public function setListscheduleAction($uuid)
    {
        return $this->setBase('listschedule', 'schedules.listschedule', $uuid);
    }

    public function delListscheduleAction($uuid)
    {
        return $this->delBase('schedules.listschedule', $uuid);
    }

    public function toggleListscheduleAction($uuid, $enabled = null)
    {
        return $this->toggleBase('schedules.listschedule', $uuid, $enabled);
    }

    public function searchMappingAction()
    {
        return $this->searchBase('customdns.mapping');
    }

    public function getMappingAction($uuid = null)
    {
        return $this->getBase('mapping', 'customdns.mapping', $uuid);
    }

    public function addMappingAction()
    {
        return $this->addBase('mapping', 'customdns.mapping');
    }

    public function setMappingAction($uuid)
    {
        return $this->setBase('mapping', 'customdns.mapping', $uuid);
    }

    public function delMappingAction($uuid)
    {
        return $this->delBase('customdns.mapping', $uuid);
    }

    public function toggleMappingAction($uuid, $enabled = null)
    {
        return $this->toggleBase('customdns.mapping', $uuid, $enabled);
    }

    public function searchRewriteAction()
    {
        return $this->searchBase('customdns.rewrite');
    }

    public function getRewriteAction($uuid = null)
    {
        return $this->getBase('rewrite', 'customdns.rewrite', $uuid);
    }

    public function addRewriteAction()
    {
        return $this->addBase('rewrite', 'customdns.rewrite');
    }

    public function setRewriteAction($uuid)
    {
        return $this->setBase('rewrite', 'customdns.rewrite', $uuid);
    }

    public function delRewriteAction($uuid)
    {
        return $this->delBase('customdns.rewrite', $uuid);
    }

    public function toggleRewriteAction($uuid, $enabled = null)
    {
        return $this->toggleBase('customdns.rewrite', $uuid, $enabled);
    }

    public function searchForwardAction()
    {
        return $this->searchBase('conditional.mapping');
    }

    public function getForwardAction($uuid = null)
    {
        return $this->getBase('forward', 'conditional.mapping', $uuid);
    }

    public function addForwardAction()
    {
        return $this->addBase('forward', 'conditional.mapping');
    }

    public function setForwardAction($uuid)
    {
        return $this->setBase('forward', 'conditional.mapping', $uuid);
    }

    public function delForwardAction($uuid)
    {
        return $this->delBase('conditional.mapping', $uuid);
    }

    public function toggleForwardAction($uuid, $enabled = null)
    {
        return $this->toggleBase('conditional.mapping', $uuid, $enabled);
    }
}
