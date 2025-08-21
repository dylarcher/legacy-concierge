#!/usr/bin/env node

/**
 * CHANGELOG.md Generator
 * Generates a changelog from Git commit history with semantic versioning support
 */

const fs = require('fs');
const { execSync } = require('child_process');
const path = require('path');

// Configuration
const CONFIG = {
    outputFile: 'CHANGELOG.md',
    projectName: 'Legacy Concierge WordPress',
    repoUrl: 'https://github.com/dylarcher/legacy-concierge',
    dateFormat: 'YYYY-MM-DD',
    commitTypes: {
        feat: { title: '🚀 Features', emoji: '🚀' },
        fix: { title: '🐛 Bug Fixes', emoji: '🐛' },
        docs: { title: '📚 Documentation', emoji: '📚' },
        style: { title: '💄 Styling', emoji: '💄' },
        refactor: { title: '♻️ Refactoring', emoji: '♻️' },
        perf: { title: '⚡ Performance', emoji: '⚡' },
        test: { title: '✅ Testing', emoji: '✅' },
        chore: { title: '🔧 Maintenance', emoji: '🔧' },
        ci: { title: '👷 CI/CD', emoji: '👷' },
        build: { title: '📦 Build', emoji: '📦' },
        revert: { title: '⏪ Reverts', emoji: '⏪' }
    },
    sections: [
        'feat', 'fix', 'perf', 'refactor', 'docs', 'style', 'test', 'chore', 'build', 'ci', 'revert'
    ]
};

class ChangelogGenerator {
    constructor() {
        this.commits = [];
        this.versions = [];
        this.currentVersion = this.getCurrentVersion();
    }

    getCurrentVersion() {
        try {
            const packageJson = JSON.parse(fs.readFileSync('package.json', 'utf8'));
            return packageJson.version || '1.0.0';
        } catch (error) {
            console.warn('Could not read version from package.json, using 1.0.0');
            return '1.0.0';
        }
    }

    getGitCommits() {
        try {
            // Get all commits with format: hash|date|author|subject|body
            const gitLog = execSync(
                'git log --pretty=format:"%H|%ai|%an|%s|%b" --no-merges',
                { encoding: 'utf8' }
            );

            return gitLog.split('\n').filter(line => line.trim()).map(line => {
                const [hash, date, author, subject, ...bodyParts] = line.split('|');
                const body = bodyParts.join('|').trim();

                return {
                    hash: hash.trim(),
                    date: new Date(date.trim()),
                    author: author.trim(),
                    subject: subject.trim(),
                    body: body,
                    type: this.extractCommitType(subject.trim()),
                    scope: this.extractCommitScope(subject.trim()),
                    breaking: this.isBreakingChange(subject.trim(), body)
                };
            });
        } catch (error) {
            console.error('Error getting git commits:', error.message);
            return [];
        }
    }

    extractCommitType(subject) {
        const match = subject.match(/^(\w+)(\(.+\))?:/);
        if (match) {
            const type = match[1].toLowerCase();
            return CONFIG.commitTypes[type] ? type : 'other';
        }

        // Detect type from keywords in subject
        if (subject.toLowerCase().includes('fix') || subject.toLowerCase().includes('bug')) return 'fix';
        if (subject.toLowerCase().includes('add') || subject.toLowerCase().includes('new')) return 'feat';
        if (subject.toLowerCase().includes('update') || subject.toLowerCase().includes('upgrade')) return 'chore';
        if (subject.toLowerCase().includes('doc')) return 'docs';
        if (subject.toLowerCase().includes('style') || subject.toLowerCase().includes('css')) return 'style';
        if (subject.toLowerCase().includes('test')) return 'test';
        if (subject.toLowerCase().includes('refactor')) return 'refactor';
        if (subject.toLowerCase().includes('perf')) return 'perf';

        return 'other';
    }

    extractCommitScope(subject) {
        const match = subject.match(/^\w+\((.+)\):/);
        return match ? match[1] : null;
    }

    isBreakingChange(subject, body) {
        return subject.includes('BREAKING CHANGE') ||
               body.includes('BREAKING CHANGE') ||
               subject.includes('!:');
    }

    groupCommitsByVersion() {
        // For now, group all commits under current version
        // In the future, this could parse git tags to separate versions
        const versions = new Map();

        // Get latest tag as previous version
        let previousVersion = '0.0.0';
        try {
            previousVersion = execSync('git describe --tags --abbrev=0', { encoding: 'utf8' }).trim();
        } catch (error) {
            // No tags found, use 0.0.0
        }

        // Group commits by date ranges or tags
        const currentVersionCommits = this.commits.filter(commit => {
            // For now, include all commits in current version
            return true;
        });

        versions.set(this.currentVersion, {
            version: this.currentVersion,
            date: new Date(),
            commits: currentVersionCommits,
            isUnreleased: true
        });

        return versions;
    }

    formatDate(date) {
        return date.toISOString().split('T')[0];
    }

    generateMarkdown() {
        let markdown = `# Changelog\n\n`;
        markdown += `All notable changes to **${CONFIG.projectName}** will be documented in this file.\n\n`;
        markdown += `The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),\n`;
        markdown += `and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).\n\n`;

        const versions = this.groupCommitsByVersion();

        for (const [versionNumber, versionData] of versions) {
            markdown += `## [${versionNumber}]`;

            if (versionData.isUnreleased) {
                markdown += ` - Unreleased\n\n`;
            } else {
                markdown += ` - ${this.formatDate(versionData.date)}\n\n`;
            }

            // Group commits by type
            const commitsByType = new Map();

            versionData.commits.forEach(commit => {
                const type = commit.type || 'other';
                if (!commitsByType.has(type)) {
                    commitsByType.set(type, []);
                }
                commitsByType.get(type).push(commit);
            });

            // Sort sections according to configuration
            const sortedTypes = CONFIG.sections.filter(type => commitsByType.has(type));
            if (commitsByType.has('other')) {
                sortedTypes.push('other');
            }

            // Add breaking changes first if any
            const breakingChanges = versionData.commits.filter(c => c.breaking);
            if (breakingChanges.length > 0) {
                markdown += `### ⚠️ BREAKING CHANGES\n\n`;
                breakingChanges.forEach(commit => {
                    markdown += `- **${commit.scope ? `${commit.scope}: ` : ''}**${this.formatCommitSubject(commit.subject)} ([${commit.hash.substring(0, 7)}](${CONFIG.repoUrl}/commit/${commit.hash}))\n`;
                });
                markdown += `\n`;
            }

            // Add sections for each commit type
            for (const type of sortedTypes) {
                const commits = commitsByType.get(type);
                if (!commits || commits.length === 0) continue;

                const typeConfig = CONFIG.commitTypes[type];
                if (typeConfig) {
                    markdown += `### ${typeConfig.title}\n\n`;
                } else {
                    markdown += `### 📝 Other Changes\n\n`;
                }

                commits.forEach(commit => {
                    const scope = commit.scope ? `**${commit.scope}**: ` : '';
                    const subject = this.formatCommitSubject(commit.subject);
                    const hash = commit.hash.substring(0, 7);
                    const commitUrl = `${CONFIG.repoUrl}/commit/${commit.hash}`;

                    markdown += `- ${scope}${subject} ([${hash}](${commitUrl}))\n`;
                });

                markdown += `\n`;
            }

            // Add contributors for this version
            const contributors = [...new Set(versionData.commits.map(c => c.author))];
            if (contributors.length > 0) {
                markdown += `### 👥 Contributors\n\n`;
                contributors.forEach(contributor => {
                    markdown += `- ${contributor}\n`;
                });
                markdown += `\n`;
            }
        }

        // Add footer with generation info
        markdown += `---\n\n`;
        markdown += `*This changelog was automatically generated on ${new Date().toISOString().split('T')[0]}*\n`;

        return markdown;
    }

    formatCommitSubject(subject) {
        // Remove conventional commit prefix if present
        return subject.replace(/^\w+(\(.+\))?:\s*/, '');
    }

    async generate() {
        console.log('🔄 Generating changelog...');

        // Get commits from git
        this.commits = this.getGitCommits();
        console.log(`📝 Found ${this.commits.length} commits`);

        // Generate markdown
        const markdown = this.generateMarkdown();

        // Write to file
        fs.writeFileSync(CONFIG.outputFile, markdown, 'utf8');

        console.log(`✅ Changelog generated: ${CONFIG.outputFile}`);
        console.log(`📊 Processed ${this.commits.length} commits for version ${this.currentVersion}`);

        // Show summary
        const typeCount = {};
        this.commits.forEach(commit => {
            const type = commit.type || 'other';
            typeCount[type] = (typeCount[type] || 0) + 1;
        });

        console.log('\n📈 Commit Summary:');
        Object.entries(typeCount).forEach(([type, count]) => {
            const emoji = CONFIG.commitTypes[type]?.emoji || '📝';
            console.log(`   ${emoji} ${type}: ${count}`);
        });
    }
}

// Run the generator
if (require.main === module) {
    const generator = new ChangelogGenerator();
    generator.generate().catch(error => {
        console.error('❌ Error generating changelog:', error);
        process.exit(1);
    });
}

module.exports = ChangelogGenerator;
